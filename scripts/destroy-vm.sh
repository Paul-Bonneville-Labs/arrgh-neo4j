#!/bin/bash

# Destroy Neo4j VM and all resources using Terraform
# This script completely removes the Neo4j deployment

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

check_terraform_state() {
    log_info "Checking Terraform state..."
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    if [ ! -f "terraform.tfstate" ]; then
        log_warn "No Terraform state file found. Nothing to destroy."
        exit 0
    fi
    
    # Check if state contains resources
    if ! terraform show -json | jq -e '.values.root_module.resources[]' > /dev/null 2>&1; then
        log_warn "No resources found in Terraform state. Nothing to destroy."
        exit 0
    fi
    
    log_info "Terraform state found with resources"
}

show_resources_to_destroy() {
    log_info "Resources that will be destroyed:"
    
    cd "$TERRAFORM_DIR"
    
    # Show plan for destruction
    terraform plan -destroy
}

confirm_destruction() {
    echo
    log_warn "WARNING: This will permanently destroy all Neo4j resources!"
    log_warn "This includes:"
    log_warn "  - VM instance and all data"
    log_warn "  - Firewall rules"
    log_warn "  - Service account"
    log_warn "  - Static IP reservation"
    echo
    
    read -p "Are you sure you want to destroy all resources? Type 'yes' to continue: " -r
    echo
    if [ "$REPLY" != "yes" ]; then
        log_info "Destruction cancelled"
        exit 0
    fi
    
    echo
    read -p "This action cannot be undone. Are you absolutely sure? Type 'DESTROY' to continue: " -r
    echo
    if [ "$REPLY" != "DESTROY" ]; then
        log_info "Destruction cancelled"
        exit 0
    fi
}

create_backup_before_destroy() {
    echo
    read -p "Do you want to create a backup before destroying? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Creating backup before destruction..."
        
        # Check if backup script exists
        if [ -f "$SCRIPT_DIR/backup-neo4j.sh" ]; then
            "$SCRIPT_DIR/backup-neo4j.sh"
        else
            log_warn "Backup script not found. Skipping backup."
        fi
    fi
}

destroy_resources() {
    log_info "Destroying Neo4j resources..."
    
    cd "$TERRAFORM_DIR"
    
    # Destroy all resources
    terraform destroy -auto-approve
    
    if [ $? -eq 0 ]; then
        log_info "All resources destroyed successfully"
    else
        log_error "Failed to destroy some resources"
        exit 1
    fi
}

cleanup_local_files() {
    echo
    read -p "Do you want to clean up local Terraform files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleaning up local files..."
        
        cd "$TERRAFORM_DIR"
        
        # Remove Terraform state files
        rm -f terraform.tfstate*
        rm -f .terraform.lock.hcl
        rm -rf .terraform/
        
        log_info "Local cleanup completed"
    fi
}

cleanup_gcp_resources() {
    echo
    read -p "Do you want to check for any orphaned GCP resources? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Checking for orphaned resources..."
        
        # Get project ID from terraform.tfvars
        if [ -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
            PROJECT_ID=$(grep -E "^project_id" "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
            
            if [ -n "$PROJECT_ID" ]; then
                gcloud config set project "$PROJECT_ID"
                
                echo "Checking for remaining firewall rules..."
                gcloud compute firewall-rules list --filter="name:neo4j"
                
                echo "Checking for remaining VM instances..."
                gcloud compute instances list --filter="name:neo4j"
                
                echo "Checking for remaining service accounts..."
                gcloud iam service-accounts list --filter="displayName:Neo4j"
                
                echo "Checking for remaining static IPs..."
                gcloud compute addresses list --filter="name:neo4j"
            fi
        fi
    fi
}

main() {
    log_info "Starting Neo4j VM destruction process..."
    
    check_terraform_state
    show_resources_to_destroy
    confirm_destruction
    create_backup_before_destroy
    destroy_resources
    cleanup_local_files
    cleanup_gcp_resources
    
    log_info "Neo4j VM destruction process completed!"
    log_info "All resources have been removed from GCP"
}

# Show usage if help is requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0"
    echo ""
    echo "This script will:"
    echo "  1. Show resources that will be destroyed"
    echo "  2. Ask for confirmation (requires typing 'yes' and 'DESTROY')"
    echo "  3. Optionally create a backup before destroying"
    echo "  4. Destroy all Terraform-managed resources"
    echo "  5. Optionally clean up local Terraform files"
    echo "  6. Optionally check for orphaned GCP resources"
    echo ""
    echo "WARNING: This action cannot be undone!"
    exit 0
fi

# Run main function
main "$@"