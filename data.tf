data "aws_vpc" "selected" {
  default = true
}

data "lacework_agent_access_token" "mesos" {
  name = var.lacework_agent_token_name
}

data "http" "current_ip" {
  # url = "https://api.ipify.org/?format=json"
  url = "https://api4.my-ip.io/ip.json"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}
