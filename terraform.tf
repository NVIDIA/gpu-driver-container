provider "aws" {
  version = "~> 1.33"
  region = "us-east-1"
}

variable "ssh_key_pub" {}
variable "ssh_host_key" {}
variable "ssh_host_key_pub" {}

data "aws_ami" "ubuntu16_04" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
}

data "template_cloudinit_config" "user_data" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = <<EOF
#cloud-config

apt:
  preserve_sources_list: true
  sources:
    docker.list:
      source: "deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE test"
      keyid: 0EBFCD88

packages:
  - docker-ce

users:
  - name: nvidia
    lock_passwd: True
    groups:
      - docker
    ssh_authorized_keys: ${file(var.ssh_key_pub)}

ssh_deletekeys: true
ssh_keys:
  ed25519_private: |
    ${indent(4, file(var.ssh_host_key))}
  ed25519_public: "${file(var.ssh_host_key_pub)}"
EOF
  }
}

resource "aws_instance" "builder" {
  ami           = "${data.aws_ami.ubuntu16_04.id}"
  instance_type = "c4.4xlarge"

  connection {
    user = "nvidia"
    agent = true
    host_key = "${file(var.ssh_host_key_pub)}"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "sudo modprobe ipmi_msghandler",
    ]
  }

  user_data = "${data.template_cloudinit_config.user_data.rendered}"
}

output "public_ip" {
  value = "${aws_instance.builder.public_ip}"
}
