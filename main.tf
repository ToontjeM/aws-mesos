provider "aws" {
  region = var.aws_default_region
}

provider "lacework" {}


resource "random_id" "id" {
  byte_length = 4
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "aws_key_pair" "ssh" {
  key_name   = "${random_id.id.hex}-ssh"
  public_key = tls_private_key.ssh.public_key_openssh
  tags       = {}
}

resource "local_file" "ssh" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.root}/mesos-ssh.key"
  file_permission = "0400"
}

resource "aws_instance" "mesos-master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh.key_name
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]

  tags = {
    Name = "Mesos-master"
  }

  provisioner "remote-exec" {
    connection {
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_pem
      host        = self.public_ip
    }

    inline = [
      "curl -sSL https://lwinttonhome.lacework.net/mgr/v1/download/8383e6c927c6d2e100ce184ee3d52a0190ba4b54f7f4424747f52659/install.sh > /tmp/install.sh",
      "chmod +x /tmp/install.sh",
      "sudo /tmp/install.sh -U https://api.lacework.net ${data.lacework_agent_access_token.mesos.token}",
      "rm -rf /tmp/lw-install.sh",
      "sudo apt update && apt upgrade -y && sudo apt autoremove -y",
      "sudo apt install openjdk-8-jdk tar wget git autoconf libtool -y",
      "sudo apt install build-essential python-dev libcurl4-nss-dev libsasl2-dev libsasl2-modules maven libapr1-dev libsvn-dev -y",
      "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/",
      "sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF",
      "DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')",
      "CODENAME=$(lsb_release -cs)",
      "echo \"deb http://repos.mesosphere.com/$${DISTRO} $${CODENAME} main\" | sudo tee /etc/apt/sources.list.d/mesosphere.list",
      "sudo apt-get update",
      "sudo apt install mesos marathon -y",
      "echo \"1\" | sudo tee /etc/zookeeper/conf/myid",
      "echo \"zk://${aws_instance.mesos-master.public_ip}:2181/mesos\" | sudo tee /etc/mesos/zk",
      "echo \"server.1=${aws_instance.mesos-master.public_ip}:2888:3888\" | sudo tee /etc/zookeeper/conf/zoo.cfg",
      "echo ${aws_instance.mesos-master.public_ip} | sudo tee /etc/mesos-master/ip",
      "cp /etc/mesos-master/ip /etc/mesos-master/hostname",
      "echo MyCluster| sudo tee /etc/mesos-master/cluster",
      "echo \"MARATHON_MASTER=zk://${aws_instance.mesos-master.public_ip}:2181/mesos\" | sudo tee -a /etc/default/marathon",
      "echo \"MARATHON_ZK=zk://${aws_instance.mesos-master.public_ip}:2181/marathon\" | sudo tee -a /etc/default/marathon",
      "sudo service mesos-slave stop",
      "echo manual | tee /etc/init/mesos-slave.override",
      "sudo service zookeeper restart",
      "sudo service mesos-master restart",
      "sudo service marathon restart"
    ]
  }
}

resource "aws_instance" "mesos-slave" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh.key_name
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]

  tags = {
    Name = "Mesos-slave"
  }

  provisioner "remote-exec" {
    connection {
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_pem
      host        = self.public_ip
    }

    inline = [
      "curl -sSL https://lwinttonhome.lacework.net/mgr/v1/download/8383e6c927c6d2e100ce184ee3d52a0190ba4b54f7f4424747f52659/install.sh > /tmp/install.sh",
      "chmod +x /tmp/install.sh",
      "sudo /tmp/install.sh -U https://api.lacework.net ${data.lacework_agent_access_token.mesos.token}",
      "rm -rf /tmp/lw-install.sh",
      "sudo apt update && apt upgrade -y && sudo apt autoremove -y",
      "sudo apt install openjdk-8-jdk tar wget git autoconf libtool -y",
      "sudo apt install build-essential python-dev libcurl4-nss-dev libsasl2-dev libsasl2-modules maven libapr1-dev libsvn-dev -y",
      "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/",
      "sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF",
      "DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')",
      "CODENAME=$(lsb_release -cs)",
      "echo \"deb http://repos.mesosphere.com/$${DISTRO} $${CODENAME} main\" | sudo tee /etc/apt/sources.list.d/mesosphere.list",
      "sudo apt update",
      "sudo apt -y install mesos",
      "sudo service zookeeper stop",
      "echo manual | sudo tee /etc/init/zookeeper.override",
      "sudo service mesos-master stop",
      "echo manual | sudo tee /etc/init/mesos-master.override",
      "echo ${aws_instance.mesos-slave.public_ip} | sudo tee /etc/mesos-slave/ip",
      "sudo cp /etc/mesos-slave/ip /etc/mesos-slave/hostname",
      "echo \"zk://${aws_instance.mesos-master.public_ip}:2181/mesos\" | sudo tee /etc/mesos/zk",
      "sudo service mesos-slave restart"
    ]
  }
}

resource "aws_security_group" "allow_traffic" {
  name   = "${random_id.id.hex}-allow-traffic"
  vpc_id = data.aws_vpc.selected.id

  ingress = [{
    description      = "SSH from current IP"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["${lookup(jsondecode(data.http.current_ip.body), "ip")}/32"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  },
  {
    description      = "8080 from all"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  },
  {
    description      = "5050 from all"
    from_port        = 5050
    to_port          = 5050
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  },
  {
    description      = "2181 from all"
    from_port        = 2181
    to_port          = 2181
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]
  
  egress = [{
    description      = "Lets talk to the world!"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]

  tags = {}
}

