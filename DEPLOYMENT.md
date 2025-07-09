# Complete Neo4j Deployment Guide

This guide covers the complete deployment process for Neo4j with custom domain `neo4j.paulbonneville.com`.

## Prerequisites

1. **Google Cloud SDK** installed and authenticated
2. **Terraform** >= 1.2.0 installed
3. **Docker** installed (for local development)
4. **DNS access** to configure `paulbonneville.com` domain
5. **Environment variables** configured

## Step 1: Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Update .env with Secret Manager values
./scripts/update-env.sh

# Verify environment variables
cat .env
```

## Step 2: DNS Configuration

### Add DNS Records

Add the following A record to your DNS provider:

```
Name: neo4j.paulbonneville.com
Type: A
Value: 130.211.30.22
TTL: 300
```

### Verify DNS

```bash
# Check DNS resolution
nslookup neo4j.paulbonneville.com
dig neo4j.paulbonneville.com

# Expected output: 130.211.30.22
```

## Step 3: Deploy Infrastructure

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

## Step 4: Monitor SSL Certificate

```bash
# Check certificate status
terraform output ssl_certificate_status

# Wait for certificate to become ACTIVE
# This can take 10-60 minutes
```

## Step 5: Verify Deployment

### Test Custom Domain

```bash
# Test HTTPS (should work after SSL cert is active)
curl -I https://neo4j.paulbonneville.com

# Test HTTP (should redirect to HTTPS)
curl -I http://neo4j.paulbonneville.com
```

### Test Direct IP Access

```bash
# Get VM IP
terraform output neo4j_ip_addresses

# Test direct IP access
curl -I http://34.63.143.68:7474
```

## Step 6: Access Neo4j

### Custom Domain (Recommended)
- **URL**: https://neo4j.paulbonneville.com
- **Username**: neo4j
- **Password**: Retrieved from Secret Manager

### Direct IP Access (Fallback)
- **URL**: http://34.63.143.68:7474
- **Username**: neo4j
- **Password**: Retrieved from Secret Manager

## Step 7: Update Applications

Update your applications to use the custom domain:

```python
# arrgh-fastapi configuration
NEO4J_URI = "bolt://34.63.143.68:7687"  # Bolt still uses direct IP
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = get_secret("neo4j-password")

# For web interface references
NEO4J_BROWSER_URL = "https://neo4j.paulbonneville.com"
```

## Troubleshooting

### DNS Issues

```bash
# Check DNS propagation
nslookup neo4j.paulbonneville.com
dig neo4j.paulbonneville.com @8.8.8.8

# Check from different locations
curl -I https://neo4j.paulbonneville.com
```

### SSL Certificate Issues

```bash
# Check certificate status
terraform output ssl_certificate_status

# If PROVISIONING, wait and check again
# If FAILED, check DNS configuration
```

### Load Balancer Issues

```bash
# Check backend service health
gcloud compute backend-services get-health neo4j-backend-service-arrgh-neo4j \
    --global --format="table(status.healthStatus)"

# Check instance health
gcloud compute instances describe neo4j-arrgh-neo4j-1 --zone=us-central1-a \
    --format="value(status)"
```

### Connection Issues

```bash
# Check firewall rules
gcloud compute firewall-rules list --filter="name:neo4j"

# Check load balancer IP
gcloud compute addresses describe neo4j-static-ip --global

# Test backend directly
curl -v http://34.63.143.68:7474
```

## Security Considerations

1. **HTTPS Only**: Custom domain enforces HTTPS
2. **Auto-redirect**: HTTP traffic is redirected to HTTPS
3. **Managed SSL**: Certificate is managed by Google Cloud
4. **Secret Management**: Credentials stored in Secret Manager
5. **Firewall Rules**: Proper network security configured

## Monitoring

```bash
# Check SSL certificate expiry
gcloud compute ssl-certificates describe neo4j-ssl-cert-arrgh-neo4j --global

# Monitor load balancer metrics
gcloud logging read "resource.type=http_load_balancer"

# Check backend health
gcloud compute backend-services get-health neo4j-backend-service-arrgh-neo4j --global
```

## Maintenance

### Update SSL Certificate

SSL certificates are automatically renewed by Google Cloud.

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

- **Custom domain**: No additional cost
- **Load balancer**: ~$18/month
- **SSL certificate**: Free (Google-managed)
- **Total estimated cost**: ~$42/month (VM + LB + storage)

## Rollback Plan

If issues occur:

```bash
# Rollback to direct IP access
# Update applications to use VM IP directly
# Remove load balancer resources if needed

terraform destroy -target=google_compute_global_forwarding_rule.neo4j_https_forwarding_rule
```

## Next Steps

1. **Monitor deployment** for 24-48 hours
2. **Update documentation** with final URLs
3. **Configure monitoring alerts**
4. **Set up automated backups**
5. **Test disaster recovery procedures**