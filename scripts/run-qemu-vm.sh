#!/bin/bash
# Run the dev workstation QEMU image directly
# This is a simpler alternative to Nomad for testing or single-host deployments
#
# Prerequisites:
#   - QEMU/KVM installed: sudo apt install qemu-kvm libvirt-daemon-system
#   - User in kvm group: sudo usermod -aG kvm $USER
#   - Built QEMU image: packer build -var 'builder=qemu' ubuntu-dev.pkr.hcl
#
# Usage:
#   ./scripts/run-qemu-vm.sh [image-path]
#
# Example:
#   ./scripts/run-qemu-vm.sh output-ubuntu-dev-vm-qemu/ubuntu-dev-vm

set -euo pipefail

# Configuration
IMAGE_PATH="${1:-output-ubuntu-dev-vm-qemu/ubuntu-dev-vm}"
VM_NAME="dev-workstation"
MEMORY="32768"        # 32GB - adjust as needed
CPUS="8"              # 8 cores - adjust as needed
SSH_PORT="2222"       # Host port for SSH forwarding
VNC_PORT="5900"       # VNC port for console access
ENABLE_KVM="yes"      # Set to "no" to disable KVM acceleration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if ! command -v qemu-system-x86_64 &> /dev/null; then
        error "QEMU not found. Install with: sudo apt install qemu-kvm"
    fi

    if [[ "$ENABLE_KVM" == "yes" ]]; then
        if [[ ! -e /dev/kvm ]]; then
            warn "/dev/kvm not found. Running without KVM acceleration (slower)."
            ENABLE_KVM="no"
        elif [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; then
            warn "Cannot access /dev/kvm. Add user to kvm group: sudo usermod -aG kvm \$USER"
            ENABLE_KVM="no"
        fi
    fi

    # Find the image
    if [[ -f "$IMAGE_PATH" ]]; then
        IMAGE_FILE="$IMAGE_PATH"
    elif [[ -f "${IMAGE_PATH}.qcow2" ]]; then
        IMAGE_FILE="${IMAGE_PATH}.qcow2"
    else
        error "Image not found at: $IMAGE_PATH\nBuild with: packer build -var 'builder=qemu' ubuntu-dev.pkr.hcl"
    fi

    log "Found image: $IMAGE_FILE"
}

# Create a working copy of the image (to preserve the original)
create_working_copy() {
    WORK_DIR="${HOME}/.local/share/dev-workstation"
    mkdir -p "$WORK_DIR"

    WORK_IMAGE="${WORK_DIR}/${VM_NAME}.qcow2"

    if [[ -f "$WORK_IMAGE" ]]; then
        log "Using existing working image: $WORK_IMAGE"
        read -p "Reset to clean state? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Creating fresh copy from base image..."
            cp "$IMAGE_FILE" "$WORK_IMAGE"
        fi
    else
        log "Creating working copy: $WORK_IMAGE"
        cp "$IMAGE_FILE" "$WORK_IMAGE"
    fi

    IMAGE_FILE="$WORK_IMAGE"
}

# Build QEMU command
build_qemu_cmd() {
    QEMU_CMD=(
        qemu-system-x86_64
        -name "$VM_NAME"
        -m "$MEMORY"
        -smp "cpus=$CPUS"
        -drive "file=$IMAGE_FILE,format=qcow2,if=virtio"
        -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
        -device "virtio-net-pci,netdev=net0"
        -vnc ":0"
        -monitor "unix:${WORK_DIR}/monitor.sock,server,nowait"
        -pidfile "${WORK_DIR}/qemu.pid"
    )

    if [[ "$ENABLE_KVM" == "yes" ]]; then
        QEMU_CMD+=(-enable-kvm -cpu host)
        log "KVM acceleration enabled"
    else
        QEMU_CMD+=(-cpu qemu64)
        warn "Running without KVM acceleration (will be slower)"
    fi

    # Add daemonize option for background running
    if [[ "${DAEMONIZE:-no}" == "yes" ]]; then
        QEMU_CMD+=(-daemonize)
    fi
}

# Start the VM
start_vm() {
    log "Starting VM..."
    log "  Memory: ${MEMORY}MB"
    log "  CPUs: $CPUS"
    log "  SSH: localhost:$SSH_PORT"
    log "  VNC: localhost:$VNC_PORT"

    echo ""
    log "Connect via SSH:"
    echo "    ssh -p $SSH_PORT developer@localhost"
    echo ""
    log "Connect via VNC:"
    echo "    vncviewer localhost:$VNC_PORT"
    echo ""

    if [[ "${DAEMONIZE:-no}" == "yes" ]]; then
        "${QEMU_CMD[@]}"
        log "VM started in background. PID: $(cat ${WORK_DIR}/qemu.pid)"
        log "Stop with: kill \$(cat ${WORK_DIR}/qemu.pid)"
    else
        log "Starting VM in foreground (Ctrl+C to stop)..."
        "${QEMU_CMD[@]}"
    fi
}

# Main
main() {
    echo "=================================="
    echo "  Dev Workstation QEMU Launcher"
    echo "=================================="
    echo ""

    check_prerequisites
    create_working_copy
    build_qemu_cmd
    start_vm
}

main "$@"
