# Complete Neo4j Deployment Guide

This guide covers the complete deployment process for Neo4j on Google Cloud Platform.

## Prerequisites

1. **Google Cloud SDK** installed and authenticated
2. **Terraform** >= 1.2.0 installed
3. **Docker** installed (for local development)
4. **Environment variables** configured

## Step 1: Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Update .env with Secret Manager values
./scripts/update-env.sh

# Verify environment variables
cat .env
```

**Note:** Replace `YOUR_INSTANCE_IP` in this guide with the actual IP address from your deployment, which can be found by running:
```bash
terraform output neo4j_ip_addresses
```

## Step 2: Deploy Infrastructure

```bash
# Navigate to deployment directory
cd neo4j-official

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply deployment
terraform apply
```

## Step 3: Verify Deployment

### Test Access

```bash
# Get VM IP
terraform output neo4j_ip_addresses

# Test direct IP access
curl -I http://YOUR_INSTANCE_IP:7474
```

## Step 4: Access Neo4j

- **URL**: http://YOUR_INSTANCE_IP:7474
- **Username**: neo4j
- **Password**: Retrieved from Secret Manager

## Step 5: Update Applications

Update your applications to use Neo4j:

```python
# arrgh-fastapi configuration
NEO4J_URI = "bolt://YOUR_INSTANCE_IP:7687"
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = get_secret("neo4j-password")
```

## Troubleshooting

### Instance Issues

```bash
# Check instance health
gcloud compute instances describe neo4j-arrgh-neo4j-1 --zone=us-central1-a \
    --format="value(status)"

# Check if Neo4j is running
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a \
    --command="sudo docker ps"
```

### Connection Issues

```bash
# Check firewall rules
gcloud compute firewall-rules list --filter="name:neo4j"

# Test connection
curl -v http://YOUR_INSTANCE_IP:7474
```

## Security Considerations

1. **Secret Management**: Credentials stored in Secret Manager
2. **Firewall Rules**: Proper network security configured
3. **SSH Access**: Limited to authorized users
4. **Network Isolation**: Dedicated VPC for Neo4j

## Monitoring

```bash
# Check instance metrics
gcloud compute instances describe neo4j-arrgh-neo4j-1 --zone=us-central1-a

# Monitor instance logs
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a \
    --command="sudo docker logs neo4j-community"
```

## Maintenance


### Scale Deployment

```bash
# Edit terraform.tfvars
node_count = 3

# Apply changes
terraform apply
```

### Update Neo4j Version

```bash
# Update Docker image in startup script
# Redeploy with terraform apply
```

## Cost Optimization

- **VM Instance**: ~$24/month (e2-medium)
- **Storage**: Included in VM cost
- **Total estimated cost**: ~$24/month

## Rollback Plan

If issues occur:

```bash
# Destroy all infrastructure
terraform destroy
```

## Next Steps

1. **Monitor deployment** for 24-48 hours
2. **Update documentation** with final URLs
3. **Configure monitoring alerts**
4. **Set up automated backups**
5. **Test disaster recovery procedures**