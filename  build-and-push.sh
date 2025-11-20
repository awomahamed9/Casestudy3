cat > build-and-push.sh << 'EOF'
#!/bin/bash
set -e

echo "Building Docker image for amd64..."
docker build --platform linux/amd64 -t hr-app:latest .

echo "Tagging for ECR..."
docker tag hr-app:latest 511000088594.dkr.ecr.eu-central-1.amazonaws.com/cs3-ma-nca-hr-app:latest

echo "Logging into ECR..."
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 511000088594.dkr.ecr.eu-central-1.amazonaws.com

echo "Pushing to ECR..."
docker push 511000088594.dkr.ecr.eu-central-1.amazonaws.com/cs3-ma-nca-hr-app:latest

echo "✅ Done!"
EOF

chmod +x build-and-push.sh