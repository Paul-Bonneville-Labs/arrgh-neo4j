# Google Cloud Secret Manager Integration

This document describes how to use Google Cloud Secret Manager to securely manage Neo4j credentials and configuration.

## Secret Manager Setup

### 1. Enable Secret Manager API

```bash
gcloud services enable secretmanager.googleapis.com
```

### 2. Create Secrets

The following secrets are automatically created and managed:

- `neo4j-username` - Neo4j username (neo4j)
- `neo4j-password` - Production Neo4j password (auto-generated)
- `neo4j-local-password` - Local development password (devpassword)
- `gcp-project-id` - GCP project ID
- `neo4j-prod-ip` - Production Neo4j IP address

### 3. List Secrets

```bash
gcloud secrets list --filter="name:neo4j OR name:gcp-project-id"
```

### 4. Access Secrets

```bash
# Get a specific secret
gcloud secrets versions access latest --secret="neo4j-password"

# Get all secrets using the script
./scripts/get-secrets.sh
```

## Using the Secrets Script

The `scripts/get-secrets.sh` script provides easy access to all secrets:

### Display Secrets
```bash
./scripts/get-secrets.sh
```

### Export to Environment Variables
```bash
# Source into current shell
source ./scripts/get-secrets.sh

# Or use eval
eval $(./scripts/get-secrets.sh --export)
```

### Script Features
- Retrieves all Neo4j configuration from Secret Manager
- Generates connection URIs automatically
- Hides sensitive passwords in output
- Supports export mode for shell integration
- Includes error handling and authentication checks

## Integration with Applications

### Python Applications (arrgh-fastapi)

```python
import subprocess

def get_secret(secret_name):
    """Retrieve secret from Google Cloud Secret Manager"""
    result = subprocess.run([
        'gcloud', 'secrets', 'versions', 'access', 'latest', 
        '--secret', secret_name
    ], capture_output=True, text=True)
    return result.stdout.strip()

# Production configuration
NEO4J_URI = f"bolt://{get_secret('neo4j-prod-ip')}:7687"
NEO4J_USER = get_secret('neo4j-username')
NEO4J_PASSWORD = get_secret('neo4j-password')
```

### Shell Scripts

```bash
#!/bin/bash

# Source secrets
source ./scripts/get-secrets.sh

# Use in script
echo "Connecting to Neo4j at $NEO4J_URI_PROD"
```

## Terraform Integration

The Terraform startup script automatically retrieves the production password from Secret Manager:

```bash
# In startup.sh
if SECRET_PASSWORD=$(gcloud secrets versions access latest --secret="neo4j-password" 2>/dev/null); then
    export admin_password="$SECRET_PASSWORD"
    echo "Using password from Secret Manager"
else
    echo "Warning: Could not retrieve password from Secret Manager, using Terraform variable"
fi
```

## Security Best Practices

### 1. IAM Permissions

Ensure proper IAM permissions for Secret Manager:

```bash
# Grant Secret Manager access to service account
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:YOUR_SERVICE_ACCOUNT@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
```

### 2. Secret Rotation

Rotate secrets regularly:

```bash
# Create new version of secret
echo "new-password" | gcloud secrets versions add neo4j-password --data-file=-

# Update Terraform deployment
cd neo4j-official
terraform apply
```

### 3. Audit Access

Monitor secret access:

```bash
# View secret access logs
gcloud logging read "resource.type=gce_instance AND jsonPayload.secret_name=neo4j-password"
```

## Environment Variables

When using Secret Manager, these environment variables are automatically populated:

```bash
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=[from neo4j-password secret]
NEO4J_LOCAL_PASSWORD=devpassword
GCP_PROJECT_ID=[from gcp-project-id secret]
NEO4J_PROD_IP=[from neo4j-prod-ip secret]
NEO4J_URI_LOCAL=bolt://localhost:7687
NEO4J_HTTP_LOCAL=http://localhost:7474
NEO4J_URI_PROD=bolt://[prod-ip]:7687
NEO4J_HTTP_PROD=http://[prod-ip]:7474
```

## Troubleshooting

### Authentication Issues

```bash
# Check gcloud authentication
gcloud auth list

# Re-authenticate if needed
gcloud auth login
gcloud auth application-default login
```

### Secret Access Issues

```bash
# Check if secret exists
gcloud secrets describe neo4j-password

# Check IAM permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID

# Test secret access
gcloud secrets versions access latest --secret="neo4j-password"
```

### Common Errors

1. **Secret not found**: Ensure secrets are created in the correct project
2. **Permission denied**: Check IAM roles and service account permissions
3. **gcloud not found**: Install Google Cloud SDK and authenticate
4. **Network issues**: Check firewall rules and connectivity

## Migration from .env

To migrate from `.env` file to Secret Manager:

1. Create secrets from existing `.env` values
2. Update application to use Secret Manager
3. Test thoroughly in development
4. Deploy to production
5. Remove sensitive values from `.env` file

This approach provides better security, centralized management, and audit trails for all sensitive configuration.