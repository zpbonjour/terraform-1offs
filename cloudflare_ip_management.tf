###   I manage several project that utilize Cloudflare.  I needed a way to quickly deploy
###   and maintain the Cloudflare IP ranges in my security groups.
###   You may need to make a variety of changes to get this working in your environment.

terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # use your profile name or convert to access keys or env vars
  region                   = "us-east-1"
  profile                  = "rootacct"
  shared_credentials_files = ["~/.aws/config"]
}

# Get current Cloudflare IP address ranges so they can be added to the inbound security groups - IPv4 ranges
data "http" "cloudflare_ipv4" {
  url = "https://www.cloudflare.com/ips-v4"
  request_headers = {
    Accept = "application/text"
  }
}
# Get current Cloudflare IP address ranges so they can be added to the inbound security groups - IPv6 ranges
data "http" "cloudflare_ipv6" {
  url = "https://www.cloudflare.com/ips-v6"
  request_headers = {
    Accept = "application/text"
  }
}

# Convert strings to sets
# I have no idea *why* this regex works, but it does.  Please open an issue if there is a better way.
# Yes, I realize there is a REST API where I can get this cleaner, but I wanted to do it without an API key.
locals {
  CloudflareAddressesIPV4 = toset(regexall("^*[0-9].*", data.http.cloudflare_ipv4.response_body))
  CloudflareAddressesIPV6 = toset(regexall("^*:*.*", data.http.cloudflare_ipv6.response_body))
}

# Get exiting VPC - replace MyVPC with your VPC name
data "aws_vpc" "vpc" {
  filter {
    name  = "tag:Name"
    values = ["MyVPC"]
  }
}

# Create Security Group - or import one using a data source
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Public internet access"
  vpc_id      = data.aws_vpc.vpc.id

  tags = {
    Name      = "public-sg"
    ManagedBy = "terraform"
  }
}

# HTTP CloudFlare OUT IPv4
resource "aws_vpc_security_group_egress_rule" "private_out_http_v4" {
  for_each          = local.CloudflareAddressesIPV4
  security_group_id = aws_security_group.public_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.key
  tags = {
    Name            = "EgressTCP80IPv4"
    Description     = "Allows Cloudflare Owned IPs TCP:80 Outbound"
    ManagedBy       = "terraform"
    CloudflareRange = each.key
  }
}

# HTTP CloudFlare OUT IPv6
resource "aws_vpc_security_group_egress_rule" "private_out_http_v6" {
  for_each          = local.CloudflareAddressesIPV6
  security_group_id = aws_security_group.public_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv6         = each.key
  tags = {
    Name            = "EgressTCP80IPv6"
    Description     = "Allows Cloudflare Owned IPs TCP:80 Outbound"
    ManagedBy       = "terraform"
    CloudflareRange = each.key
  }
}
# HTTPS CloudFlare OUT IPv4
resource "aws_vpc_security_group_egress_rule" "private_out_https_v4" {
  for_each          = local.CloudflareAddressesIPV4
  security_group_id = aws_security_group.public_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.key
  tags = {
    Name            = "EgressTCP443IPv4"
    Description     = "Allows Cloudflare Owned IPs TCP:443 Outbound"
    ManagedBy       = "terraform"
    CloudflareRange = each.key
  }
}

# HTTPS CloudFlare OUT IPv6
resource "aws_vpc_security_group_egress_rule" "private_out_https_v6" {
  for_each          = local.CloudflareAddressesIPV6
  security_group_id = aws_security_group.public_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv6         = each.key
  tags = {
    Name            = "EgressTCP443IPv4"
    Description     = "Allows Cloudflare Owned IPs TCP:443 Outbound"
    ManagedBy       = "terraform"
    CloudflareRange = each.key
  }
}

# HTTP CloudFlare IN IPv4
resource "aws_vpc_security_group_ingress_rule" "public_in_http_v4" {
  for_each          = local.CloudflareAddressesIPV4
  security_group_id = aws_security_group.public_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.key
  tags = {
    Name        = "IngressTCP80IPv4"
    Description = "Allows Cloudflare Owned IPs TCP:80 Inbound"
    ManagedBy   = "terraform"
  }
}

# HTTP CloudFlare IN IPv6
resource "aws_vpc_security_group_ingress_rule" "public_in_http_v6" {
  for_each          = local.CloudflareAddressesIPV6
  security_group_id = aws_security_group.public_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv6         = each.key
  tags = {
    Name            = "IngressTCP80IPv6"
    Description     = "Allows Cloudflare Owned IPs TCP:80 Inbound"
    ManagedBy       = "terraform"
    CloudflareRange = each.key
  }
}
# HTTPS CloudFlare IN IPv4
resource "aws_vpc_security_group_ingress_rule" "public_in_https_v4" {
  for_each          = local.CloudflareAddressesIPV4
  security_group_id = aws_security_group.public_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.key
  tags = {
    Name            = "IngressTCP443IPv4"
    Description     = "Allows Cloudflare Owned IPs TCP:443 Inbound"
    ManagedBy       = "terraform"
    CloudflareRange = each.key
  }
}

# HTTPS CloudFlare IN IPv6
resource "aws_vpc_security_group_ingress_rule" "public_in_https_v6" {
  for_each          = local.CloudflareAddressesIPV6
  security_group_id = aws_security_group.public_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv6         = each.key
  tags = {
    Name            = "IngressTCP443IPv4"
    Description     = "Allows Cloudflare Owned IPs TCP:443 Inbound"
    ManagedBy       = "terraform"
    CloudflareRange = each.key
  }
}
