# Nomad Job Specification for Dev Workstation VM
# This job runs the Packer-built QEMU image on a Nomad cluster
#
# Prerequisites:
# 1. Build the QEMU image: packer build -var 'builder=qemu' ubuntu-dev.pkr.hcl
# 2. Copy the image to /opt/nomad/qemu-images/ on the target node
#
# Usage:
#   nomad job run nomad/dev-workstation.nomad.hcl

variable "image_name" {
  description = "Name of the QCOW2 image in /opt/nomad/qemu-images/"
  type        = string
  default     = "ubuntu-dev-vm.qcow2"
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for automatic Tailnet join"
  type        = string
  default     = ""
}

job "dev-workstation" {
  datacenters = ["dc1"]
  type        = "service"

  # Run on NUC where the image is stored
  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "nuc"
  }

  group "vm" {
    count = 1

    # Ensure stable networking
    network {
      mode = "host"

      # SSH access
      port "ssh" {
        static = 2222
        to     = 22
      }

      # VNC for console access (optional)
      port "vnc" {
        static = 5900
        to     = 5900
      }
    }

    # Restart policy
    restart {
      attempts = 3
      interval = "10m"
      delay    = "30s"
      mode     = "fail"
    }

    # Reschedule policy
    reschedule {
      attempts       = 5
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = false
    }

    task "dev-vm" {
      driver = "qemu"

      # Resource requirements - adjust based on your Nomad host
      resources {
        cpu    = 8000   # 8 CPU cores (in MHz, adjust for your host)
        memory = 16384  # 16GB RAM
      }

      # QEMU configuration
      config {
        # Image source - full path to image
        image_path = "/opt/nomad/qemu-images/${var.image_name}"

        # VM hardware configuration
        accelerator = "kvm"

        # Additional QEMU arguments
        args = [
          "-cpu", "host",
          "-smp", "8,sockets=1,cores=8,threads=1",
          "-m", "16384",
          "-enable-kvm",
          "-netdev", "user,id=user.0,hostfwd=tcp::2222-:22",
          "-device", "virtio-net,netdev=user.0"
        ]
      }

      # Template for Tailscale setup script (injected via cloud-init)
      template {
        data = <<-EOF
          #!/bin/bash
          # Auto-join Tailnet on boot
          {{ if env "TAILSCALE_AUTH_KEY" }}
          sudo tailscale up --authkey={{ env "TAILSCALE_AUTH_KEY" }} --hostname=dev-workstation-nomad
          {{ end }}
        EOF

        destination = "local/tailscale-setup.sh"
        perms       = "0755"
      }

      # Environment variables
      env {
        TAILSCALE_AUTH_KEY = var.tailscale_auth_key
      }

      # Logs
      logs {
        max_files     = 5
        max_file_size = 10
      }
    }
  }

  # Update strategy - careful with VMs
  update {
    max_parallel      = 1
    min_healthy_time  = "60s"
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
  }
}
