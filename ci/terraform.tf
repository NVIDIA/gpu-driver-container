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

data "template_cloudinit_config" "ubuntu16_04" {
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
    sudo:  ALL=(ALL) NOPASSWD:ALL
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

resource "aws_instance" "ubuntu16_04" {
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

  user_data = "${data.template_cloudinit_config.ubuntu16_04.rendered}"
}

output "public_ip_ubuntu16_04" {
  value = "${aws_instance.ubuntu16_04.public_ip}"
}

# Launch the latest CoreOS instance
data "aws_ami" "coreos" {
  most_recent = true

  owners = ["679593333241"]

  filter {
    name = "name"
    values = ["CoreOS-stable-*"]
  }
}

data "ignition_user" "nvidia" {
  name = "nvidia"
  ssh_authorized_keys = ["${file(var.ssh_key_pub)}"]
  primary_group = "docker"
  groups = ["sudo"]
}

data "ignition_file" "sshd_keys" {
    filesystem = "root"
    path = "/etc/ssh/ssh_host_ed25519_key"
    mode = 384
    content {
        content = "${file(var.ssh_host_key)}"
	mime = "text/plain"
    }
}

data "ignition_file" "sshd_config" {
    filesystem = "root"
    path = "/etc/ssh/sshd_config"
    mode = 384
    content {
      content = <<EOF
HostKey /etc/ssh/ssh_host_ed25519_key
UsePrivilegeSeparation sandbox
UseDNS no

PermitRootLogin no
AllowUsers nvidia
AuthenticationMethods publickey
EOF
      mime = "text/plain"
     }
}

data "ignition_config" "coreos_ignition_config" {
  users = ["${data.ignition_user.nvidia.id}"]
  files = ["${data.ignition_file.sshd_keys.id}", "${data.ignition_file.sshd_config.id}"]
}

resource "aws_instance" "coreos_builder" {
  ami           = "${data.aws_ami.coreos.id}"
  instance_type = "c4.4xlarge"

  connection {
    user = "nvidia"
    agent = true
    host_key = "${file(var.ssh_host_key_pub)}"
  }

  provisioner "file" {
    source = "./coreos/build.sh"
    destination = "~/build.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl stop update-engine",
      "sudo systemctl stop locksmithd",
      "sudo modprobe -a loop ipmi_msghandler",
      "chmod +x ~/build.sh"
    ]
  }
  user_data = "${data.ignition_config.coreos_ignition_config.rendered}"
}

output "public_ip_coreos" {
  value = "${aws_instance.coreos_builder.public_ip}"
}
