#!/bin/bash

# Start Neo4j Docker container on the VM
# This script can be run locally to start Neo4j on a deployed VM

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
        log_warn "VM is not running. Starting VM..."
        gcloud compute instances start "$VM_NAME" --zone="$VM_ZONE"
        
        # Wait for VM to be running
        log_info "Waiting for VM to start..."
        while true; do
            STATUS=$(gcloud compute instances describe "$VM_NAME" --zone="$VM_ZONE" --format="value(status)")
            if [ "$STATUS" = "RUNNING" ]; then
                break
            fi
            sleep 5
        done
        log_info "VM is now running"
    else
        log_info "VM is already running"
    fi
}

start_neo4j() {
    log_info "Starting Neo4j container..."
    
    # SSH into the VM and start Neo4j
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << 'EOF'
        cd /opt/neo4j
        
        # Check if container is already running
        if docker-compose ps | grep -q "Up"; then
            echo "Neo4j container is already running"
        else
            echo "Starting Neo4j container..."
            docker-compose up -d
            
            # Wait for Neo4j to be ready
            echo "Waiting for Neo4j to be ready..."
            for i in {1..30}; do
                if curl -s http://localhost:7474 > /dev/null 2>&1; then
                    echo "Neo4j is ready!"
                    break
                fi
                echo "Waiting... ($i/30)"
                sleep 10
            done
        fi
        
        # Show container status
        echo "Container status:"
        docker-compose ps
EOF
    
    if [ $? -eq 0 ]; then
        log_info "Neo4j started successfully"
    else
        log_error "Failed to start Neo4j"
        exit 1
    fi
}

verify_neo4j_accessible() {
    log_info "Verifying Neo4j is accessible..."
    
    # Test HTTP endpoint
    if curl -s "http://$VM_IP:7474" > /dev/null; then
        log_info "Neo4j HTTP endpoint is accessible"
    else
        log_warn "Neo4j HTTP endpoint is not accessible yet"
    fi
    
    # Test Bolt endpoint
    if timeout 5 bash -c "</dev/tcp/$VM_IP/7687" 2>/dev/null; then
        log_info "Neo4j Bolt endpoint is accessible"
    else
        log_warn "Neo4j Bolt endpoint is not accessible yet"
    fi
}

display_connection_info() {
    log_info "Neo4j connection information:"
    echo
    echo "========================================"
    echo "Neo4j Connection Information"
    echo "========================================"
    echo "HTTP Browser: http://$VM_IP:7474"
    echo "Bolt URL: neo4j://$VM_IP:7687"
    echo "SSH Command: ssh -i ~/.ssh/id_rsa neo4j@$VM_IP"
    echo
    echo "Default Credentials:"
    echo "Username: neo4j"
    echo "Password: (check your terraform.tfvars file)"
    echo "========================================"
}

main() {
    log_info "Starting Neo4j service..."
    
    check_vm_exists
    get_vm_info
    check_vm_running
    start_neo4j
    verify_neo4j_accessible
    display_connection_info
    
    log_info "Neo4j start process completed!"
}

# Run main function
main "$@"