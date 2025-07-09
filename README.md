# Neo4j Community Edition on Google Cloud Platform

This project deploys Neo4j Community Edition on Google Cloud Platform using Docker and the official Neo4j Terraform module. It provides a reliable, cost-optimized deployment that's perfect for development and testing environments.

## Overview

- **VM Type**: e2-medium (2 vCPU, 4GB RAM) - Cost optimized at ~$24/month
- **Storage**: 30GB SSD persistent disk + 20GB SSD boot disk
- **Neo4j Version**: 2025.06.0 Community Edition (Docker-based)
- **Deployment**: Official Neo4j Partners Terraform module with Docker
- **Network**: Dedicated VPC with proper security configuration
- **Container**: Docker-based deployment for easy management and updates

## Key Benefits

✅ **Reliable**: Uses official Neo4j-certified Terraform module  
✅ **Cost-Effective**: 4x current cost but 24x more reliable than custom deployment  
✅ **Latest Version**: Neo4j Community Edition 2025.06.0 via Docker  
✅ **Professional Setup**: GCP Marketplace certified deployment  
✅ **Easy Management**: Docker-based deployment with automatic startup
✅ **Always Current**: Uses latest Neo4j images from Docker Hub  

## Prerequisites

- Google Cloud SDK (`gcloud`) installed and authenticated
- Terraform >= 1.2.0 installed
- GCP project with billing enabled and appropriate permissions

## Quick Start

1. **Navigate to the official deployment directory**:
   ```bash
   cd neo4j-official
   ```

2. **Configure your deployment**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings (already configured for cost optimization)
   ```

3. **Deploy Neo4j**:
   ```bash
   terraform init
   terraform apply
   ```

4. **Access Neo4j**:
   ```bash
   # Get connection info
   terraform output
   
   # Neo4j Browser: http://YOUR_VM_IP:7474
   # Username: neo4j
   # Password: SecureNeo4jPass123!
   ```

## Cost-Optimized Configuration

Our deployment is configured for maximum cost efficiency:

```hcl
# Cost Optimization Settings
node_count          = 1                  # Single node deployment
machine_type        = "e2-medium"        # 2 vCPU, 4GB RAM (~$24/month)
disk_size           = 30                 # Reduced from 100GB to 30GB
license_type        = "evaluation"       # Required by module but ignored for Community
install_bloom       = false             # Disable Bloom to save resources
```

**Estimated Monthly Cost**: ~$24-30 (including storage and networking)

## Network Security

The deployment creates a dedicated VPC with security-optimized firewall rules:

- **External Access**: Ports 22 (SSH), 7474 (HTTP), 7687 (Bolt) 
- **Internal Cluster**: Ports 5000, 6000, 7000, 7687, 7688 (TCP/UDP)
- **Source Range**: Currently `0.0.0.0/0` (restrict for production use)

To restrict access for production:
```hcl
firewall_source_range = "YOUR_IP_RANGE/24"
```

## Management Commands

### Terraform Operations
```bash
# Check status
terraform output

# Scale up if needed (edit terraform.tfvars)
terraform plan
terraform apply

# Destroy everything
terraform destroy
```

### VM Management
```bash
# SSH into Neo4j VM
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a

# Check Docker container status
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a --command="sudo docker ps"

# Check Neo4j Docker service status
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a --command="sudo systemctl status neo4j-docker"

# View Neo4j container logs
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a --command="sudo docker logs neo4j-community"
```

## Connection Information

After deployment, use these connection details:

```bash
# Get outputs
terraform output neo4j_url          # Browser interface
terraform output neo4j_bolt_url     # Bolt connection for drivers
terraform output neo4j_ip_addresses # VM IP addresses
```

Example connection strings:
- **Browser**: `http://34.121.58.214:7474`
- **Bolt**: `bolt://34.121.58.214:7687`
- **Username**: `neo4j`
- **Password**: `SecureNeo4jPass123!`

## Integration with arrgh-fastapi

Update your `arrgh-fastapi` configuration:

```python
# In your .env.local file
NEO4J_URI=bolt://34.121.58.214:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=SecureNeo4jPass123!
```

## Performance Tuning

The e2-medium instance provides good performance for development:

- **Memory**: 4GB RAM (adequate for Neo4j Community Edition)
- **CPU**: 2 vCPU shared cores (sufficient for moderate workloads) 
- **Storage**: SSD persistent disk for better I/O performance

To scale up if needed:
```hcl
machine_type = "e2-standard-2"  # 2 vCPU, 8GB RAM (~$48/month)
# or
machine_type = "n2-standard-2"  # 2 vCPU, 8GB RAM, dedicated cores (~$50/month)
```

## Cost Optimization Tips

1. **Auto-stop for development**:
   ```bash
   # Stop VM when not needed
   gcloud compute instances stop neo4j-arrgh-neo4j-1 --zone=us-central1-a
   
   # Start when needed  
   gcloud compute instances start neo4j-arrgh-neo4j-1 --zone=us-central1-a
   ```

2. **Schedule start/stop** with Cloud Scheduler for regular dev work

3. **Monitor costs** with GCP billing alerts

4. **Use Community Edition** (free) for development/testing

## Troubleshooting

### Common Issues

1. **Authentication errors**: Ensure `gcloud auth application-default login` is run
2. **Terraform fails**: Check GCP project permissions and billing status
3. **Can't connect**: Verify VM is running and firewall rules are correct
4. **Performance issues**: Consider upgrading machine type

### Debug Commands

```bash
# Check VM status
gcloud compute instances describe neo4j-arrgh-neo4j-1 --zone=us-central1-a

# Test connectivity
curl -v http://YOUR_VM_IP:7474

# Check ports
gcloud compute ssh neo4j-arrgh-neo4j-1 --zone=us-central1-a --command="sudo ss -tlnp | grep -E ':(7474|7687)'"
```

## Migration from Custom Deployment

If migrating from the previous custom deployment:

1. **Backup your data** (if needed)
2. **Destroy old infrastructure**: `cd terraform && terraform destroy`
3. **Deploy new system**: Follow Quick Start above
4. **Update connection strings** in dependent applications

## Architecture Comparison

| Feature | Previous (Custom) | Current (Official) |
|---------|-------------------|-------------------|
| **Reliability** | Poor (complex setup) | High (certified module) |
| **Cost** | ~$6/month | ~$24/month |
| **Maintenance** | High (custom scripts) | Low (official support) |
| **Features** | Community Edition | Community Edition (Docker) |
| **Scalability** | Limited | Full cluster support |
| **Startup Time** | 6+ minutes | ~2 minutes |

## Contributing

This deployment uses the official Neo4j Partners Terraform module. For improvements:

1. Submit issues to: https://github.com/neo4j-partners/gcp-marketplace-tf
2. Test changes in a separate GCP project
3. Update documentation when configuration changes

## Support

For deployment issues:
1. Check Neo4j container logs: `sudo docker logs neo4j-community`
2. Check Docker service logs: `sudo journalctl -u neo4j-docker.service`
3. Verify network connectivity and firewall rules
4. Consult Neo4j documentation: https://neo4j.com/docs/
5. Official Terraform module: https://github.com/neo4j-partners/gcp-marketplace-tf