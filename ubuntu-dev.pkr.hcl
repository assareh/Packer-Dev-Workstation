packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "vm_name" {
  type    = string
  default = "ubuntu-dev-vm"
}

variable "ssh_username" {
  type    = string
  default = "developer"
}

variable "ssh_password" {
  type    = string
  default = "developer"
  sensitive = true
}

variable "disk_size" {
  type    = number
  default = 512000  # 500GB
}

variable "memory" {
  type    = number
  default = 32768   # 32GB
}

variable "cpus" {
  type    = number
  default = 6
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
}

source "vmware-iso" "ubuntu" {
  vm_name       = var.vm_name
  guest_os_type = "ubuntu-64"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"

  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size

  disk_type_id = "0"  # Sparse disk

  http_directory = "http"

  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{.HTTPIP}}:{{.HTTPPort}}/'",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  vmx_data = {
    "ethernet0.virtualdev" = "vmxnet3"
    "ethernet0.present"    = "TRUE"
    "ethernet0.connectionType" = "nat"
  }

  # Export as OVA
  format = "ova"
}

build {
  sources = ["source.vmware-iso.ubuntu"]

  # Wait for cloud-init to finish
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  # Install VMware Tools dependencies
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y open-vm-tools"
    ]
  }

  # Upload tmux configuration
  provisioner "file" {
    source      = "config/.tmux.conf"
    destination = "/tmp/tmux.conf"
  }

  # Run main provisioning script
  provisioner "shell" {
    script = "scripts/provision.sh"
  }

  # Upload first-boot setup script
  provisioner "file" {
    source      = "scripts/first-boot-setup.sh"
    destination = "/tmp/first-boot-setup.sh"
  }

  # Setup first-boot service
  provisioner "shell" {
    script = "scripts/setup-first-boot-service.sh"
  }

  # Cleanup
  provisioner "shell" {
    script = "scripts/cleanup.sh"
  }
}
