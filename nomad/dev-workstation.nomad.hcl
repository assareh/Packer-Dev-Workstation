# Nomad Job Specification for Dev Workstation VM
# This job runs the Packer-built QEMU image on a Nomad cluster
#
# Prerequisites:
# 1. Build the QEMU image: packer build -var 'builder=qemu' ubuntu-dev.pkr.hcl
# 2. Upload the qcow2 image to an accessible location (HTTP server, S3, etc.)
# 3. Update the artifact source below with your image URL
#
# Usage:
#   nomad job run nomad/dev-workstation.nomad.hcl

variable "image_url" {
  description = "URL to the QCOW2 image built by Packer"
  type        = string
  default     = ""
}

variable "image_checksum" {
  description = "SHA256 checksum of the QCOW2 image"
  type        = string
  default     = ""
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for automatic Tailnet join"
  type        = string
  default     = ""
}

job "dev-workstation" {
  datacenters = ["dc1"]
  type        = "service"

  # Spread constraint - don't co-locate with other dev VMs
  constraint {
    operator  = "distinct_hosts"
    value     = "true"
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
        memory = 32768  # 32GB RAM

        # Alternative: use memory_max for overcommit
        # memory     = 16384
        # memory_max = 65536
      }

      # QEMU configuration
      config {
        # Image source - downloaded at task start
        image_path = "local/ubuntu-dev-vm.qcow2"

        # VM hardware configuration
        accelerator = "kvm"

        # Port forwarding handled by network stanza
        port_map {
          ssh = 22
          vnc = 5900
        }

        # Additional QEMU arguments for better performance
        args = [
          "-cpu", "host",
          "-smp", "8,sockets=1,cores=8,threads=1",
          "-m", "32768",
          "-enable-kvm",
          "-device", "virtio-net-pci,netdev=net0",
          "-netdev", "user,id=net0,hostfwd=tcp::${NOMAD_PORT_ssh}-:22",
          "-vnc", ":0",
          "-daemonize"
        ]
      }

      # Download the QCOW2 image artifact
      artifact {
        source      = var.image_url
        destination = "local/"

        options {
          checksum = var.image_checksum != "" ? "sha256:${var.image_checksum}" : ""
        }
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
    max_parallel     = 1
    min_healthy_time = "60s"
    healthy_deadline = "10m"
    auto_revert      = true
  }
}
