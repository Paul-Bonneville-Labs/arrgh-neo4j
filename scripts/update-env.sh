#!/bin/bash

# Update .env file with actual values from Google Cloud Secret Manager
# This script keeps the local .env file in sync with Secret Manager values

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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    log_error ".env file not found at $ENV_FILE"
    exit 1
fi

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    log_error "Not authenticated with gcloud. Please run 'gcloud auth login' first."
    exit 1
fi

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

# Update .env file with actual values
main() {
    log_info "Updating .env file with values from Google Cloud Secret Manager..."
    
    # Get all secrets
    NEO4J_USERNAME=$(get_secret "neo4j-username")
    NEO4J_PASSWORD=$(get_secret "neo4j-password")
    NEO4J_LOCAL_PASSWORD=$(get_secret "neo4j-local-password")
    GCP_PROJECT_ID=$(get_secret "gcp-project-id")
    NEO4J_PROD_IP=$(get_secret "neo4j-prod-ip")
    ALERT_EMAIL=$(get_secret "alert-email")
    
    # Create backup of existing .env
    cp "$ENV_FILE" "$ENV_FILE.backup"
    log_info "Created backup: $ENV_FILE.backup"
    
    # Update .env file
    sed -i.tmp "s|NEO4J_AUTH=.*|NEO4J_AUTH=$NEO4J_USERNAME/$NEO4J_PASSWORD|g" "$ENV_FILE"
    sed -i.tmp "s|NEO4J_PASSWORD=.*|NEO4J_PASSWORD=$NEO4J_PASSWORD|g" "$ENV_FILE"
    sed -i.tmp "s|NEO4J_USERNAME=.*|NEO4J_USERNAME=$NEO4J_USERNAME|g" "$ENV_FILE"
    sed -i.tmp "s|NEO4J_PASSWORD_LOCAL=.*|NEO4J_PASSWORD_LOCAL=$NEO4J_LOCAL_PASSWORD|g" "$ENV_FILE"
    sed -i.tmp "s|NEO4J_PASSWORD_PROD=.*|NEO4J_PASSWORD_PROD=$NEO4J_PASSWORD|g" "$ENV_FILE"
    sed -i.tmp "s|GCP_PROJECT_ID=.*|GCP_PROJECT_ID=$GCP_PROJECT_ID|g" "$ENV_FILE"
    sed -i.tmp "s|NEO4J_URI_PROD=.*|NEO4J_URI_PROD=bolt://$NEO4J_PROD_IP:7687|g" "$ENV_FILE"
    sed -i.tmp "s|NEO4J_HTTP_PROD=.*|NEO4J_HTTP_PROD=http://$NEO4J_PROD_IP:7474|g" "$ENV_FILE"
    sed -i.tmp "s|ALERT_EMAIL=.*|ALERT_EMAIL=$ALERT_EMAIL|g" "$ENV_FILE"
    
    # Clean up temporary file
    rm -f "$ENV_FILE.tmp"
    
    log_info "Successfully updated .env file with current Secret Manager values"
    log_info "Values updated:"
    echo "  NEO4J_USERNAME=$NEO4J_USERNAME"
    echo "  NEO4J_PASSWORD=[UPDATED]"
    echo "  NEO4J_LOCAL_PASSWORD=$NEO4J_LOCAL_PASSWORD"
    echo "  GCP_PROJECT_ID=$GCP_PROJECT_ID"
    echo "  NEO4J_PROD_IP=$NEO4J_PROD_IP"
    echo "  ALERT_EMAIL=$ALERT_EMAIL"
    echo "  NEO4J_URI_PROD=bolt://$NEO4J_PROD_IP:7687"
    echo "  NEO4J_HTTP_PROD=http://$NEO4J_PROD_IP:7474"
    
    log_info "Backup saved as: $ENV_FILE.backup"
}

# Show usage
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0"
    echo ""
    echo "Update .env file with actual values from Google Cloud Secret Manager"
    echo ""
    echo "This script:"
    echo "  1. Retrieves all secrets from Secret Manager"
    echo "  2. Creates a backup of the current .env file"
    echo "  3. Updates .env with the actual values"
    echo "  4. Preserves the structure and comments"
    echo ""
    echo "Example:"
    echo "  $0    # Update .env with current secret values"
    exit 0
fi

# Run main function
main "$@"