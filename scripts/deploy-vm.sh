#!/bin/bash

# Deploy Neo4j VM using Terraform
# This script automates the deployment of Neo4j Community Edition on Google Cloud Platform

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is authenticated with gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Not authenticated with gcloud. Please run 'gcloud auth login' first."
        exit 1
    fi
    
    # Check if terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Please create it from terraform.tfvars.example"
        log_info "Run: cp $TERRAFORM_DIR/terraform.tfvars.example $TERRAFORM_DIR/terraform.tfvars"
        log_info "Then edit terraform.tfvars with your project details"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

validate_gcp_project() {
    log_info "Validating GCP project..."
    
    # Get project ID from terraform.tfvars
    PROJECT_ID=$(grep -E "^project_id" "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "project_id not found in terraform.tfvars"
        exit 1
    fi
    
    # Set the project
    gcloud config set project "$PROJECT_ID"
    
    # Check if project exists and is accessible
    if ! gcloud projects describe "$PROJECT_ID" &> /dev/null; then
        log_error "Cannot access project '$PROJECT_ID'. Please check project ID and permissions."
        exit 1
    fi
    
    # Check if required APIs are enabled
    log_info "Checking required APIs..."
    
    required_apis=(
        "compute.googleapis.com"
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${required_apis[@]}"; do
        if ! gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            log_warn "API $api is not enabled. Enabling now..."
            gcloud services enable "$api"
        fi
    done
    
    log_info "GCP project validation completed"
}

generate_ssh_key() {
    log_info "Checking SSH key..."
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        log_warn "SSH key not found. Generating new SSH key..."
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N "" -C "neo4j-vm-key"
    else
        log_info "SSH key found at ~/.ssh/id_rsa"
    fi
}

deploy_terraform() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log_info "Planning deployment..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    echo
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    # Apply deployment
    log_info "Applying deployment..."
    terraform apply tfplan
    
    # Clean up plan file
    rm -f tfplan
    
    log_info "Terraform deployment completed"
}

wait_for_vm_ready() {
    log_info "Waiting for VM to be ready..."
    
    # Get VM details from Terraform output
    VM_NAME=$(terraform output -raw vm_name)
    VM_ZONE=$(terraform output -raw vm_zone)
    VM_IP=$(terraform output -raw vm_external_ip)
    
    # Wait for VM to be running
    log_info "Waiting for VM instance to be running..."
    while true; do
        STATUS=$(gcloud compute instances describe "$VM_NAME" --zone="$VM_ZONE" --format="value(status)")
        if [ "$STATUS" = "RUNNING" ]; then
            break
        fi
        log_info "VM status: $STATUS. Waiting..."
        sleep 10
    done
    
    # Wait for SSH to be available
    log_info "Waiting for SSH to be available..."
    while true; do
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no neo4j@"$VM_IP" 'exit' &>/dev/null; then
            break
        fi
        log_info "SSH not ready yet. Waiting..."
        sleep 10
    done
    
    # Wait for Neo4j to be ready
    log_info "Waiting for Neo4j to be ready..."
    for i in {1..30}; do
        if curl -s "http://$VM_IP:7474" &> /dev/null; then
            log_info "Neo4j is ready!"
            break
        fi
        log_info "Neo4j not ready yet. Waiting... ($i/30)"
        sleep 10
    done
}

display_connection_info() {
    log_info "Deployment completed successfully!"
    echo
    echo "========================================"
    echo "Neo4j Connection Information"
    echo "========================================"
    
    cd "$TERRAFORM_DIR"
    
    echo "HTTP Browser: $(terraform output -raw neo4j_http_url)"
    echo "Bolt URL: $(terraform output -raw neo4j_bolt_url)"
    echo "SSH Command: $(terraform output -raw ssh_command)"
    echo "VM External IP: $(terraform output -raw vm_external_ip)"
    echo "VM Internal IP: $(terraform output -raw vm_internal_ip)"
    echo
    echo "Default Credentials:"
    echo "Username: neo4j"
    echo "Password: (check your terraform.tfvars file)"
    echo
    echo "========================================"
    echo "Next Steps:"
    echo "1. Open Neo4j Browser: $(terraform output -raw neo4j_http_url)"
    echo "2. Log in with the credentials above"
    echo "3. Update your arrgh-fastapi configuration with the connection details"
    echo "4. Test the connection from your Cloud Run service"
    echo "========================================"
}

main() {
    log_info "Starting Neo4j VM deployment..."
    
    check_prerequisites
    validate_gcp_project
    generate_ssh_key
    deploy_terraform
    wait_for_vm_ready
    display_connection_info
    
    log_info "Deployment process completed!"
}

# Run main function
main "$@"