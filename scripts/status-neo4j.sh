#!/bin/bash

# Check Neo4j VM and service status
# This script provides comprehensive status information

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_status() {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

check_terraform_state() {
    log_info "Checking Terraform deployment status..."
    
    if [ ! -d "$TERRAFORM_DIR" ] || [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        log_error "No Terraform deployment found. Please run deploy-vm.sh first."
        return 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Check if VM exists in Terraform state
    if ! terraform show -json | jq -e '.values.root_module.resources[] | select(.type == "google_compute_instance" and .name == "neo4j_vm")' > /dev/null 2>&1; then
        log_error "VM not found in Terraform state."
        return 1
    fi
    
    log_status "Terraform deployment found"
    return 0
}

get_vm_info() {
    log_info "Getting VM information..."
    
    cd "$TERRAFORM_DIR"
    
    VM_NAME=$(terraform output -raw vm_name 2>/dev/null || echo "")
    VM_ZONE=$(terraform output -raw vm_zone 2>/dev/null || echo "")
    VM_IP=$(terraform output -raw vm_external_ip 2>/dev/null || echo "")
    
    if [ -z "$VM_NAME" ] || [ -z "$VM_ZONE" ] || [ -z "$VM_IP" ]; then
        log_error "Failed to get VM information from Terraform outputs"
        return 1
    fi
    
    log_status "VM Name: $VM_NAME"
    log_status "VM Zone: $VM_ZONE"
    log_status "VM IP: $VM_IP"
    return 0
}

check_vm_status() {
    log_info "Checking VM status..."
    
    STATUS=$(gcloud compute instances describe "$VM_NAME" --zone="$VM_ZONE" --format="value(status)" 2>/dev/null || echo "UNKNOWN")
    
    case "$STATUS" in
        "RUNNING")
            log_status "VM Status: ${GREEN}RUNNING${NC}"
            return 0
            ;;
        "TERMINATED")
            log_status "VM Status: ${RED}STOPPED${NC}"
            return 1
            ;;
        "STOPPING")
            log_status "VM Status: ${YELLOW}STOPPING${NC}"
            return 1
            ;;
        "STAGING")
            log_status "VM Status: ${YELLOW}STARTING${NC}"
            return 1
            ;;
        *)
            log_status "VM Status: ${RED}$STATUS${NC}"
            return 1
            ;;
    esac
}

check_ssh_connectivity() {
    log_info "Checking SSH connectivity..."
    
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no neo4j@"$VM_IP" 'exit' &>/dev/null; then
        log_status "SSH: ${GREEN}ACCESSIBLE${NC}"
        return 0
    else
        log_status "SSH: ${RED}NOT ACCESSIBLE${NC}"
        return 1
    fi
}

check_neo4j_container() {
    log_info "Checking Neo4j container status..."
    
    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" 'exit' &>/dev/null; then
        log_status "Neo4j Container: ${RED}CANNOT CHECK (SSH FAILED)${NC}"
        return 1
    fi
    
    CONTAINER_STATUS=$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << 'EOF'
        cd /opt/neo4j
        if docker-compose ps --services --filter "status=running" | grep -q "neo4j"; then
            echo "RUNNING"
        elif docker-compose ps --services | grep -q "neo4j"; then
            echo "STOPPED"
        else
            echo "NOT_FOUND"
        fi
EOF
)
    
    case "$CONTAINER_STATUS" in
        "RUNNING")
            log_status "Neo4j Container: ${GREEN}RUNNING${NC}"
            return 0
            ;;
        "STOPPED")
            log_status "Neo4j Container: ${RED}STOPPED${NC}"
            return 1
            ;;
        *)
            log_status "Neo4j Container: ${RED}NOT FOUND${NC}"
            return 1
            ;;
    esac
}

check_neo4j_http() {
    log_info "Checking Neo4j HTTP endpoint..."
    
    if curl -s --max-time 10 "http://$VM_IP:7474" > /dev/null 2>&1; then
        log_status "Neo4j HTTP (7474): ${GREEN}ACCESSIBLE${NC}"
        return 0
    else
        log_status "Neo4j HTTP (7474): ${RED}NOT ACCESSIBLE${NC}"
        return 1
    fi
}

check_neo4j_bolt() {
    log_info "Checking Neo4j Bolt endpoint..."
    
    if timeout 5 bash -c "</dev/tcp/$VM_IP/7687" 2>/dev/null; then
        log_status "Neo4j Bolt (7687): ${GREEN}ACCESSIBLE${NC}"
        return 0
    else
        log_status "Neo4j Bolt (7687): ${RED}NOT ACCESSIBLE${NC}"
        return 1
    fi
}

get_system_resources() {
    log_info "Getting system resource usage..."
    
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << 'EOF'
        echo "System Resources:"
        echo "=================="
        
        # Memory usage
        free -h | grep -E "^(Mem|Swap)"
        
        echo ""
        echo "Disk Usage:"
        df -h / | tail -n 1
        
        echo ""
        echo "Neo4j Data Directory:"
        if [ -d "/opt/neo4j/data" ]; then
            du -sh /opt/neo4j/data
        else
            echo "Not found"
        fi
        
        echo ""
        echo "Docker Container Stats:"
        if docker ps | grep -q "arrgh-neo4j"; then
            docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" arrgh-neo4j
        else
            echo "Container not running"
        fi
EOF
}

get_neo4j_logs() {
    log_info "Getting recent Neo4j logs..."
    
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no neo4j@"$VM_IP" << 'EOF'
        echo "Recent Neo4j Logs:"
        echo "=================="
        
        cd /opt/neo4j
        if docker-compose ps | grep -q "Up"; then
            docker-compose logs --tail=20 neo4j
        else
            echo "Container not running"
        fi
EOF
}

show_connection_info() {
    log_info "Connection information:"
    
    echo
    echo "========================================"
    echo "Neo4j Connection Information"
    echo "========================================"
    echo "HTTP Browser: http://$VM_IP:7474"
    echo "Bolt URL: neo4j://$VM_IP:7687"
    echo "SSH Command: ssh -i ~/.ssh/id_rsa neo4j@$VM_IP"
    echo "VM External IP: $VM_IP"
    echo
    echo "Default Credentials:"
    echo "Username: neo4j"
    echo "Password: (check your terraform.tfvars file)"
    echo "========================================"
}

main() {
    log_info "Checking Neo4j deployment status..."
    echo
    
    # Check Terraform deployment
    if ! check_terraform_state; then
        exit 1
    fi
    
    # Get VM information
    if ! get_vm_info; then
        exit 1
    fi
    
    echo
    echo "========================================"
    echo "Status Summary"
    echo "========================================"
    
    # Check VM status
    VM_RUNNING=false
    if check_vm_status; then
        VM_RUNNING=true
    fi
    
    # Only check services if VM is running
    if [ "$VM_RUNNING" = true ]; then
        check_ssh_connectivity
        check_neo4j_container
        check_neo4j_http
        check_neo4j_bolt
        
        echo
        echo "========================================"
        echo "System Information"
        echo "========================================"
        get_system_resources
        
        if [ "$1" = "--logs" ] || [ "$1" = "-l" ]; then
            echo
            echo "========================================"
            echo "Recent Logs"
            echo "========================================"
            get_neo4j_logs
        fi
        
        echo
        show_connection_info
    else
        log_warn "VM is not running. Start it with: ./start-neo4j.sh"
    fi
    
    echo
    log_info "Status check completed!"
}

# Show usage if help is requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--logs]"
    echo ""
    echo "Options:"
    echo "  (no args)  Show basic status information"
    echo "  --logs     Include recent Neo4j logs in output"
    echo "  --help     Show this help message"
    exit 0
fi

# Run main function
main "$@"