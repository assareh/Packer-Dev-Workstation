packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
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

variable "ssh_public_key" {
  type        = string
  description = "SSH public key to add to authorized_keys"
  default     = ""
}

variable "builder" {
  type        = string
  description = "Which builder to use: 'vmware' for Mac mini/VMware Fusion, 'qemu' for Nomad/Linux host"
  default     = "vmware"

  validation {
    condition     = contains(["vmware", "qemu"], var.builder)
    error_message = "Builder must be 'vmware' or 'qemu'."
  }
}

variable "qemu_accelerator" {
  type        = string
  description = "QEMU accelerator to use (kvm, hvf, tcg)"
  default     = "kvm"
}

variable "qemu_output_format" {
  type        = string
  description = "Output format for QEMU builds (qcow2, raw)"
  default     = "qcow2"
}

source "vmware-iso" "ubuntu" {
  vm_name       = var.vm_name
  guest_os_type = "ubuntu-64"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"
  ssh_handshake_attempts = 100

  # Enable SSH debugging
  ssh_pty = true

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

  # Network adapter type - let Packer handle connection type
  vmx_data = {
    "ethernet0.virtualdev" = "vmxnet3"
    "ethernet0.present"    = "TRUE"
  }

  # Use NAT networking (VM gets its own IP, not shared with host)
  network = "nat"

  # Export as OVA
  format = "ova"
}

# QEMU source for Nomad/Linux hosts
source "qemu" "ubuntu" {
  vm_name       = var.vm_name

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"
  ssh_handshake_attempts = 100

  cpus      = var.cpus
  memory    = var.memory
  disk_size = "${var.disk_size}M"

  accelerator = var.qemu_accelerator
  format      = var.qemu_output_format

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

  # Network configuration for QEMU
  net_device     = "virtio-net"
  disk_interface = "virtio"

  # Headless mode for server builds
  headless = true

  # VNC for debugging if needed
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 5999

  # QEMU binary (auto-detected on most systems)
  qemu_binary = ""

  # Output directory
  output_directory = "output-${var.vm_name}-qemu"
}

build {
  # Use dynamic source selection based on builder variable
  sources = var.builder == "vmware" ? ["source.vmware-iso.ubuntu"] : ["source.qemu.ubuntu"]

  # Wait for cloud-init to finish
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }

  # Update system
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  # Install hypervisor-specific guest tools
  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = var.builder == "vmware" ? [
      "sudo apt-get install -y open-vm-tools"
    ] : [
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent"
    ]
  }

  # Upload tmux configuration
  provisioner "file" {
    source      = "config/.tmux.conf"
    destination = "/tmp/tmux.conf"
  }

  # Run main provisioning script
  provisioner "shell" {
    environment_vars = [
      "SSH_PUBLIC_KEY=${var.ssh_public_key}"
    ]
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
