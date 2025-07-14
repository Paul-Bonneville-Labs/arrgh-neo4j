# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neo4j deployment project for Google Cloud Platform that provides both local development and production deployment capabilities. The project uses the official Neo4j Partners Terraform module for reliable, cost-optimized deployment.

## Architecture

- **Infrastructure**: Terraform-based deployment using official Neo4j Partners GCP module
- **Local Development**: Docker-based Neo4j Community Edition 2025.06.0
- **Production**: GCP VM (e2-medium) running Neo4j in Docker containers
- **Configuration**: Environment-based with Secret Manager integration
- **Network**: Dedicated VPC with security-optimized firewall rules

## Common Commands

### Local Development
```bash
# Start Neo4j locally for development
docker run -d --name neo4j-dev -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/devpassword neo4j:2025.06.0

# Stop local Neo4j
docker stop neo4j-dev

# View local logs
docker logs neo4j-dev

# Remove local container
docker rm neo4j-dev
```

### Production Deployment
```bash
# Deploy infrastructure
cd neo4j-official
terraform init
terraform plan
terraform apply

# Get deployment outputs
terraform output neo4j_ip_addresses
terraform output neo4j_url
terraform output neo4j_bolt_url

# Destroy infrastructure
terraform destroy
```

### Environment Management
```bash
# Update environment variables from Secret Manager
./scripts/update-env.sh

# Copy environment template
cp .env.example .env
```

### Instance Management
```bash
# SSH into production VM
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a

# Check Docker container status on VM
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a --command="sudo docker ps"

# View Neo4j container logs
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a --command="sudo docker logs neo4j-community"

# Check Neo4j Docker service status
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a --command="sudo systemctl status neo4j-docker"

# Stop/start production instance for cost optimization
gcloud compute instances stop neo4j-arrgh-neo4j-1 --zone=us-central1-a
gcloud compute instances start neo4j-arrgh-neo4j-1 --zone=us-central1-a
```

## Key Directory Structure

```
.
├── neo4j-official/              # Official Neo4j Terraform module deployment
│   ├── main.tf                  # Main Terraform configuration
│   ├── terraform.tfvars.example # Configuration template
│   ├── modules/neo4j/           # Neo4j deployment module
│   └── test/                    # Deployment test scripts
├── scripts/
│   ├── update-env.sh           # Secret Manager to .env sync script
│   └── get-secrets.sh          # Secret retrieval utility
├── .env                        # Environment variables (local copy)
├── .env.example               # Environment template
├── README.md                  # Main project documentation
└── DEPLOYMENT.md             # Deployment guide
```

## Configuration Files

- `neo4j-official/terraform.tfvars` - Production configuration (cost-optimized for e2-medium)
- `.env` - Environment variables for local/production connection strings
- `neo4j-official/terraform.tfvars.example` - Configuration template

## Development Workflow

1. **Local Development**: Use Docker Neo4j container for development work
2. **Environment Setup**: Run `./scripts/update-env.sh` to sync with Secret Manager
3. **Production Deployment**: Use Terraform in `neo4j-official/` directory
4. **Testing**: Verify connectivity with `curl http://INSTANCE_IP:7474`

## Secret Management

All sensitive configuration is stored in Google Cloud Secret Manager:
- `neo4j-username` - Neo4j username (typically 'neo4j')
- `neo4j-password` - Production Neo4j password
- `neo4j-local-password` - Local development password
- `gcp-project-id` - GCP project identifier
- `neo4j-prod-ip` - Production instance IP address

Use `./scripts/update-env.sh` to sync these values to your local `.env` file.

## Connection Information

### Local Development
- Neo4j Browser: http://localhost:7474
- Bolt Connection: bolt://localhost:7687
- Credentials: neo4j/devpassword

### Production
- Neo4j Browser: http://INSTANCE_IP:7474
- Bolt Connection: bolt://INSTANCE_IP:7687
- Credentials: Retrieved from Secret Manager

## Cost Optimization

- **Current deployment**: ~$24/month (e2-medium VM)
- **Development strategy**: Use local Docker for daily work
- **Cost saving**: Stop/start production instance when not needed
- **VM specs**: 2 vCPU, 4GB RAM, 30GB SSD storage

## Troubleshooting

### Common Issues
- **Port conflicts**: Ensure 7474/7687 are available locally
- **Authentication**: Run `gcloud auth application-default login`
- **Terraform failures**: Check GCP permissions and billing
- **Connection issues**: Verify firewall rules and VM status

### Debug Commands
```bash
# Test local connectivity
curl -v http://localhost:7474

# Test production connectivity  
curl -v http://INSTANCE_IP:7474

# Check production VM status
gcloud compute instances describe neo4j-arrgh-neo4j-1 --zone=us-central1-a

# Check firewall rules
gcloud compute firewall-rules list --filter="name:neo4j"
```