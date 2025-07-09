#!/bin/bash

# Get secrets from Google Cloud Secret Manager
# This script retrieves Neo4j configuration from Google Cloud Secret Manager

set -e

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

# Check if gcloud is installed and authenticated
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Not authenticated with gcloud. Please run 'gcloud auth login' first."
        exit 1
    fi
}

# Get secret from Secret Manager
get_secret() {
    local secret_name=$1
    local secret_value
    
    if ! secret_value=$(gcloud secrets versions access latest --secret="$secret_name" 2>/dev/null); then
        log_error "Failed to retrieve secret: $secret_name"
        return 1
    fi
    
    echo "$secret_value"
}

# Main function to retrieve all secrets
main() {
    log_info "Retrieving secrets from Google Cloud Secret Manager..."
    
    check_gcloud
    
    # Get all secrets
    NEO4J_USERNAME=$(get_secret "neo4j-username")
    NEO4J_PASSWORD=$(get_secret "neo4j-password")
    NEO4J_LOCAL_PASSWORD=$(get_secret "neo4j-local-password")
    GCP_PROJECT_ID=$(get_secret "gcp-project-id")
    NEO4J_PROD_IP=$(get_secret "neo4j-prod-ip")
    ALERT_EMAIL=$(get_secret "alert-email")
    
    # Export as environment variables
    export NEO4J_USERNAME
    export NEO4J_PASSWORD
    export NEO4J_LOCAL_PASSWORD
    export GCP_PROJECT_ID
    export NEO4J_PROD_IP
    export ALERT_EMAIL
    
    # Generate connection URIs
    export NEO4J_URI_LOCAL="bolt://localhost:7687"
    export NEO4J_HTTP_LOCAL="http://localhost:7474"
    export NEO4J_URI_PROD="bolt://${NEO4J_PROD_IP}:7687"
    export NEO4J_HTTP_PROD="http://${NEO4J_PROD_IP}:7474"
    
    log_info "Secrets retrieved successfully!"
    
    # Display (without showing passwords)
    echo "Environment variables set:"
    echo "  NEO4J_USERNAME=$NEO4J_USERNAME"
    echo "  NEO4J_PASSWORD=[HIDDEN]"
    echo "  NEO4J_LOCAL_PASSWORD=[HIDDEN]"
    echo "  GCP_PROJECT_ID=$GCP_PROJECT_ID"
    echo "  NEO4J_PROD_IP=$NEO4J_PROD_IP"
    echo "  ALERT_EMAIL=$ALERT_EMAIL"
    echo "  NEO4J_URI_LOCAL=$NEO4J_URI_LOCAL"
    echo "  NEO4J_HTTP_LOCAL=$NEO4J_HTTP_LOCAL"
    echo "  NEO4J_URI_PROD=$NEO4J_URI_PROD"
    echo "  NEO4J_HTTP_PROD=$NEO4J_HTTP_PROD"
}

# Show usage
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Retrieve Neo4j configuration from Google Cloud Secret Manager"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  --export      Export as environment variables (for sourcing)"
    echo ""
    echo "Examples:"
    echo "  $0              # Display secrets"
    echo "  source $0       # Source into current shell"
    echo "  eval \$($0 --export)  # Export into current shell"
    exit 0
fi

# Export mode for sourcing
if [ "$1" = "--export" ]; then
    check_gcloud
    
    NEO4J_USERNAME=$(get_secret "neo4j-username")
    NEO4J_PASSWORD=$(get_secret "neo4j-password")
    NEO4J_LOCAL_PASSWORD=$(get_secret "neo4j-local-password")
    GCP_PROJECT_ID=$(get_secret "gcp-project-id")
    NEO4J_PROD_IP=$(get_secret "neo4j-prod-ip")
    ALERT_EMAIL=$(get_secret "alert-email")
    
    echo "export NEO4J_USERNAME='$NEO4J_USERNAME'"
    echo "export NEO4J_PASSWORD='$NEO4J_PASSWORD'"
    echo "export NEO4J_LOCAL_PASSWORD='$NEO4J_LOCAL_PASSWORD'"
    echo "export GCP_PROJECT_ID='$GCP_PROJECT_ID'"
    echo "export NEO4J_PROD_IP='$NEO4J_PROD_IP'"
    echo "export ALERT_EMAIL='$ALERT_EMAIL'"
    echo "export NEO4J_URI_LOCAL='bolt://localhost:7687'"
    echo "export NEO4J_HTTP_LOCAL='http://localhost:7474'"
    echo "export NEO4J_URI_PROD='bolt://${NEO4J_PROD_IP}:7687'"
    echo "export NEO4J_HTTP_PROD='http://${NEO4J_PROD_IP}:7474'"
    exit 0
fi

# Run main function
main "$@"