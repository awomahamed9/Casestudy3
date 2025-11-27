#!/bin/bash

log() {
    echo "$(date): $1" >> /var/log/openvpn-setup.log
    echo "$1"
}

log "Starting OpenVPN server setup..."

yum update -y
amazon-linux-extras install -y epel
yum install -y openvpn easy-rsa

echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

log "OpenVPN and Easy-RSA installed"

cd /etc/openvpn
cp -r /usr/share/easy-rsa/3/* .

./easyrsa init-pki
echo "cs3-ma-nca-ca" | ./easyrsa build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa build-client-full client nopass
./easyrsa gen-dh

openvpn --genkey --secret ta.key

log "Certificates and keys generated"

cat > /etc/openvpn/server.conf << SERVERCONF
port 1194
proto udp
dev tun

ca pki/ca.crt
cert pki/issued/server.crt
key pki/private/server.key
dh pki/dh.pem
tls-auth ta.key 0

server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /etc/openvpn/ipp.txt

push "route 10.0.0.0 255.255.0.0"
push "dhcp-option DNS ${dns_server}"

cipher AES-256-GCM
auth SHA256
keepalive 10 120
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384

user nobody
group nobody
persist-key
persist-tun

status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
mute 20

client-to-client

compress lz4-v2
push "compress lz4-v2"
SERVERCONF

log "Server configuration created"

iptables -t nat -A POSTROUTING -s ${vpn_client_cidr} -d ${vpc_cidr} -j RETURN
iptables -t nat -A POSTROUTING -s ${vpn_client_cidr} -o eth0 -j MASQUERADE
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp --dport 1194 -j ACCEPT

iptables-save > /etc/iptables.rules

cat > /etc/rc.local << 'RCLOCAL'
#!/bin/bash
iptables-restore < /etc/iptables.rules
exit 0
RCLOCAL
chmod +x /etc/rc.local

log "Firewall configured"

systemctl start openvpn@server
systemctl enable openvpn@server

log "OpenVPN server started"

mkdir -p /etc/openvpn/client-configs

cat > /etc/openvpn/client-configs/client.ovpn << CLIENTCONF
client
dev tun
proto udp
remote $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3
compress lz4-v2

<ca>
$(sudo cat /etc/openvpn/pki/ca.crt)
</ca>

<cert>
$(sudo cat /etc/openvpn/pki/issued/client.crt)
</cert>

<key>
$(sudo cat /etc/openvpn/pki/private/client.key)
</key>

<tls-auth>
$(sudo cat /etc/openvpn/ta.key)
</tls-auth>
CLIENTCONF

log "Client configuration created with inline certificates"

chown ec2-user:ec2-user /etc/openvpn/client-configs/client.ovpn
chmod 600 /etc/openvpn/client-configs/client.ovpn

cp /etc/openvpn/client-configs/client.ovpn /home/ec2-user/client.ovpn
chown ec2-user:ec2-user /home/ec2-user/client.ovpn
chmod 600 /home/ec2-user/client.ovpn

log "Client configuration created securely"

cat > /home/ec2-user/openvpn-status.sh << 'STATUSSCRIPT'
#!/bin/bash
echo "=== OpenVPN Status ==="
echo "Service Status: $(systemctl is-active openvpn@server)"
echo "Connected Clients:"
if [ -f /var/log/openvpn-status.log ]; then
    grep "CLIENT_LIST" /var/log/openvpn-status.log 2>/dev/null || echo "No clients connected"
else
    echo "Status log not available yet"
fi
echo ""
echo "=== Server Info ==="
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "VPN Network: ${vpn_client_cidr}"
echo "VPC Network: ${vpc_cidr}"
echo ""
echo "=== Secure Download ==="
echo "SCP command: scp -i ~/.ssh/${key_name}.pem ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):client.ovpn ./"
echo "Config location: /home/ec2-user/client.ovpn"
STATUSSCRIPT

chmod +x /home/ec2-user/openvpn-status.sh

sleep 10

if systemctl is-active --quiet openvpn@server; then
    log "SUCCESS: OpenVPN server is running"
else
    log "ERROR: OpenVPN server failed to start"
    systemctl status openvpn@server >> /var/log/openvpn-setup.log
fi

log "OpenVPN server setup completed successfully"
log "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
log "Client config: Use SCP to download /home/ec2-user/client.ovpn"
log "SCP command: scp -i ~/.ssh/${key_name}.pem ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):client.ovpn ./"
log "VPN provides access to VPC: ${vpc_cidr}"
log "Check status with: ./openvpn-status.sh"
