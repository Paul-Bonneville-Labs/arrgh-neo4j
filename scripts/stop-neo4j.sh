#!/bin/bash

# Stop Neo4j Docker container on the VM
# This script can be run locally to stop Neo4j on a deployed VM

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_vm_exists() {
    log_info "Checking if VM exists..."
    
    if [ ! -d "$TERRAFORM_DIR" ] || [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        log_error "No Terraform state found. Please run deploy-vm.sh first."
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Check if VM exists in Terraform state
    if ! terraform show -json | jq -e '.values.root_module.resources[] | select(.type == "google_compute_instance" and .name == "neo4j_vm")' > /dev/null 2>&1; then
        log_error "VM not found in Terraform state. Please run deploy-vm.sh first."
        exit 1
    fi
    
    log_info "VM found in Terraform state"
}

get_vm_info() {
    log_info "Getting VM information..."
    
    cd "$TERRAFORM_DIR"
    
    VM_NAME=$(terraform output -raw vm_name)
    VM_ZONE=$(terraform output -raw vm_zone)
    VM_IP=$(terraform output -raw vm_external_ip)
    
    if [ -z "$VM_NAME" ] || [ -z "$VM_ZONE" ] || [ -z "$VM_IP" ]; then
        log_error "Failed to get VM information from Terraform outputs"
        exit 1
    fi
    
    log_info "VM Name: $VM_NAME"
    log_info "VM Zone: $VM_ZONE"
    log_info "VM IP: $VM_IP"
}

check_vm_running() {
    log_info "Checking VM status..."
    
    STATUS=$(gcloud compute instances describe "$VM_NAME" --zone="$VM_ZONE" --format="value(status)")
    
    if [ "$STATUS" != "RUNNING" ]; then
        log_warn "VM is not running. Neo4j is already stopped."
        return 0
    else
        log_info "VM is running"
        return 1
    fi
}

stop_neo4j() {
    log_info "Stopping Neo4j container..."
    
    # SSH into the VM and stop Neo4j
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << 'EOF'
        cd /opt/neo4j
        
        # Check if container is running
        if docker-compose ps | grep -q "Up"; then
            echo "Stopping Neo4j container..."
            docker-compose down
            
            # Wait for container to stop
            echo "Waiting for Neo4j to stop..."
            for i in {1..10}; do
                if ! docker-compose ps | grep -q "Up"; then
                    echo "Neo4j stopped successfully"
                    break
                fi
                echo "Waiting... ($i/10)"
                sleep 2
            done
        else
            echo "Neo4j container is not running"
        fi
        
        # Show container status
        echo "Container status:"
        docker-compose ps
EOF
    
    if [ $? -eq 0 ]; then
        log_info "Neo4j stopped successfully"
    else
        log_error "Failed to stop Neo4j"
        exit 1
    fi
}

stop_vm() {
    echo
    read -p "Do you want to stop the VM as well to save costs? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping VM..."
        gcloud compute instances stop "$VM_NAME" --zone="$VM_ZONE"
        
        # Wait for VM to stop
        log_info "Waiting for VM to stop..."
        while true; do
            STATUS=$(gcloud compute instances describe "$VM_NAME" --zone="$VM_ZONE" --format="value(status)")
            if [ "$STATUS" = "TERMINATED" ]; then
                break
            fi
            sleep 5
        done
        log_info "VM stopped successfully"
    else
        log_info "VM left running"
    fi
}

main() {
    log_info "Stopping Neo4j service..."
    
    check_vm_exists
    get_vm_info
    
    if check_vm_running; then
        log_info "VM is not running, Neo4j is already stopped"
        return 0
    fi
    
    stop_neo4j
    stop_vm
    
    log_info "Neo4j stop process completed!"
}

# Run main function
main "$@"