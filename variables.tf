variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "cs3-ma-nca"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "key_pair_name" {
  type    = string
  default = "case3-keypair"
}

variable "my_ip_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  default   = "MySecurePass123!"
  sensitive = true
}

variable "notification_email" {
  type    = string
  default = "549500@student.fontys.nl"
}