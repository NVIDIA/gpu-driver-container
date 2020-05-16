provider "aws" {
	region = "us-west-2"
}

provider "ignition" {
  version = "1.1.0"
}

provider "template" {
}

variable "ssh_key_pub" {}
variable "project_name" {}
variable "ci_pipeline_id" {}

data "aws_ami" "ubuntu16_04" {
	most_recent = true

	owners = ["099720109477"]

	filter {
		name = "name"
		values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
	}
}

data "template_cloudinit_config" "ubuntu16_04" {
	gzip          = true
	base64_encode = true

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
EOF
	}
}

resource "aws_instance" "ubuntu16_04" {
	ami           = data.aws_ami.ubuntu16_04.id
	instance_type = "c4.4xlarge"

	tags = {
		Name = "${var.project_name}-${var.ci_pipeline_id}-ubuntu16_04"
		product = "cloud-native"
		project = var.project_name
		environment = "cicd"
	}

	root_block_device {
		volume_size = 40
	}

	security_groups = ["default", "allow_ssh"]

	connection {
		user = "nvidia"
		host = self.public_ip
		agent = true
	}

	provisioner "remote-exec" {
		inline = [
			"cloud-init status --wait",
			"sudo modprobe ipmi_msghandler",
		]
	}

	user_data = data.template_cloudinit_config.ubuntu16_04.rendered
}

output "public_ip_ubuntu16_04" {
	value = aws_instance.ubuntu16_04.public_ip
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
	ssh_authorized_keys = [file(var.ssh_key_pub)]
	primary_group = "docker"
	groups = ["sudo"]
}

data "ignition_config" "coreos_ignition_config" {
	users = [data.ignition_user.nvidia.id]
}

resource "aws_instance" "coreos_builder" {
	ami           = data.aws_ami.coreos.id
	instance_type = "c4.4xlarge"

	tags = {
		Name = "${var.project_name}-${var.ci_pipeline_id}-coreos"
		product = "cloud-native"
		project = var.project_name
		environment = "cicd"
	}

	root_block_device {
		volume_size = 40
	}

	security_groups = ["default", "allow_ssh"]

	connection {
		user = "nvidia"
		host = self.public_ip
		agent = true
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

	user_data = data.ignition_config.coreos_ignition_config.rendered
}

output "public_ip_coreos" {
	value = "${aws_instance.coreos_builder.public_ip}"
}
