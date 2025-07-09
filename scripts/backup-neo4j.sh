#!/bin/bash

# Backup Neo4j database from the VM
# This script creates a backup of the Neo4j database and optionally downloads it locally

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
BACKUP_DIR="$PROJECT_ROOT/backups"

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
        log_error "VM is not running. Please start the VM first."
        exit 1
    else
        log_info "VM is running"
    fi
}

create_backup() {
    log_info "Creating Neo4j backup..."
    
    # Generate backup filename with timestamp
    BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILENAME="neo4j_backup_${BACKUP_TIMESTAMP}.tar.gz"
    
    # SSH into the VM and create backup
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << EOF
        cd /opt/neo4j
        
        # Check if Neo4j is running
        if ! docker-compose ps | grep -q "Up"; then
            echo "Warning: Neo4j container is not running. Starting it first..."
            docker-compose up -d
            
            # Wait for Neo4j to be ready
            echo "Waiting for Neo4j to be ready..."
            for i in {1..30}; do
                if curl -s http://localhost:7474 > /dev/null 2>&1; then
                    echo "Neo4j is ready!"
                    break
                fi
                echo "Waiting... (\$i/30)"
                sleep 10
            done
        fi
        
        # Create backup directory
        mkdir -p /opt/neo4j/backups
        
        # Stop Neo4j temporarily for consistent backup
        echo "Stopping Neo4j for backup..."
        docker-compose stop neo4j
        
        # Create backup archive
        echo "Creating backup archive..."
        tar -czf "/opt/neo4j/backups/${BACKUP_FILENAME}" \
            -C /opt/neo4j \
            data logs import
        
        # Restart Neo4j
        echo "Restarting Neo4j..."
        docker-compose up -d
        
        # Wait for Neo4j to be ready
        echo "Waiting for Neo4j to be ready..."
        for i in {1..30}; do
            if curl -s http://localhost:7474 > /dev/null 2>&1; then
                echo "Neo4j is ready!"
                break
            fi
            echo "Waiting... (\$i/30)"
            sleep 10
        done
        
        echo "Backup created: /opt/neo4j/backups/${BACKUP_FILENAME}"
        ls -lh "/opt/neo4j/backups/${BACKUP_FILENAME}"
EOF
    
    if [ $? -eq 0 ]; then
        log_info "Backup created successfully on VM"
    else
        log_error "Failed to create backup"
        exit 1
    fi
}

download_backup() {
    echo
    read -p "Do you want to download the backup locally? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Downloading backup locally..."
        
        # Create local backup directory
        mkdir -p "$BACKUP_DIR"
        
        # Download backup from VM
        scp -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
            neo4j@"$VM_IP":/opt/neo4j/backups/"$BACKUP_FILENAME" \
            "$BACKUP_DIR/"
        
        if [ $? -eq 0 ]; then
            log_info "Backup downloaded to: $BACKUP_DIR/$BACKUP_FILENAME"
        else
            log_error "Failed to download backup"
            exit 1
        fi
    else
        log_info "Backup left on VM at: /opt/neo4j/backups/$BACKUP_FILENAME"
    fi
}

list_backups() {
    log_info "Listing available backups on VM..."
    
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << 'EOF'
        if [ -d "/opt/neo4j/backups" ]; then
            echo "Available backups:"
            ls -lh /opt/neo4j/backups/
        else
            echo "No backups found"
        fi
EOF
    
    if [ -d "$BACKUP_DIR" ]; then
        echo
        log_info "Local backups:"
        ls -lh "$BACKUP_DIR"/ 2>/dev/null || echo "No local backups found"
    fi
}

cleanup_old_backups() {
    echo
    read -p "Do you want to clean up old backups (keep last 5)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleaning up old backups..."
        
        # Clean up VM backups
        ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << 'EOF'
            if [ -d "/opt/neo4j/backups" ]; then
                cd /opt/neo4j/backups
                echo "Cleaning up old backups (keeping last 5)..."
                ls -t neo4j_backup_*.tar.gz | tail -n +6 | xargs -r rm -f
                echo "VM backup cleanup completed"
            fi
EOF
        
        # Clean up local backups
        if [ -d "$BACKUP_DIR" ]; then
            cd "$BACKUP_DIR"
            ls -t neo4j_backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
            log_info "Local backup cleanup completed"
        fi
    fi
}

main() {
    log_info "Starting Neo4j backup process..."
    
    # Parse command line arguments
    if [ "$1" = "list" ]; then
        check_vm_exists
        get_vm_info
        check_vm_running
        list_backups
        exit 0
    elif [ "$1" = "cleanup" ]; then
        check_vm_exists
        get_vm_info
        check_vm_running
        cleanup_old_backups
        exit 0
    fi
    
    check_vm_exists
    get_vm_info
    check_vm_running
    create_backup
    download_backup
    cleanup_old_backups
    
    log_info "Neo4j backup process completed!"
}

# Show usage if help is requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [list|cleanup]"
    echo ""
    echo "Options:"
    echo "  (no args)  Create a new backup"
    echo "  list       List available backups"
    echo "  cleanup    Clean up old backups (keep last 5)"
    echo "  --help     Show this help message"
    exit 0
fi

# Run main function
main "$@"