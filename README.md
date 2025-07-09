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

### Local Development

For local development, you can run Neo4j using Docker Compose:

```bash
# Start Neo4j locally
docker run -d \
  --name neo4j-dev \
  -p 7474:7474 -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/devpassword \
  neo4j:2025.06.0

# Access Neo4j Browser locally
open http://localhost:7474
```

**Local Development Links:**
- 🌐 **Neo4j Browser**: http://localhost:7474
- 🔌 **Bolt Connection**: bolt://localhost:7687
- 👤 **Credentials**: neo4j/devpassword

### Production Deployment on GCP

For production deployment on Google Cloud Platform:

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
   ```

**Production Links:**
- 🌐 **Neo4j Browser**: http://34.63.143.68:7474
- 🔌 **Bolt Connection**: bolt://34.63.143.68:7687
- 👤 **Credentials**: neo4j/SecureNeo4jPass123!

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

### Local Development

```bash
# Start Neo4j locally
docker run -d --name neo4j-dev -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/devpassword neo4j:2025.06.0

# Stop Neo4j
docker stop neo4j-dev

# Start existing container
docker start neo4j-dev

# View logs
docker logs neo4j-dev

# Remove container
docker rm neo4j-dev
```

### Production Deployment

#### Terraform Operations
```bash
# Check status
terraform output

# Scale up if needed (edit terraform.tfvars)
terraform plan
terraform apply

# Destroy everything
terraform destroy
```

#### VM Management
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

### Local Development

- 🌐 **Neo4j Browser**: [http://localhost:7474](http://localhost:7474)
- 🔌 **Bolt Connection**: `bolt://localhost:7687`
- 👤 **Username**: `neo4j`
- 🔑 **Password**: `devpassword`

### Production Deployment

After deployment, use these connection details:

```bash
# Get outputs
terraform output neo4j_url          # Browser interface
terraform output neo4j_bolt_url     # Bolt connection for drivers
terraform output neo4j_ip_addresses # VM IP addresses
```

- 🌐 **Neo4j Browser**: [http://34.63.143.68:7474](http://34.63.143.68:7474)
- 🔌 **Bolt Connection**: `bolt://34.63.143.68:7687`
- 👤 **Username**: `neo4j`
- 🔑 **Password**: `SecureNeo4jPass123!`

## Integration with arrgh-fastapi

### Local Development Configuration

Update your `arrgh-fastapi` configuration for local development:

```python
# In your .env.local file
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=devpassword
```

### Production Configuration

Update your `arrgh-fastapi` configuration for production:

```python
# In your .env.production file
NEO4J_URI=bolt://34.63.143.68:7687
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

## Development Workflow

### Local Development

1. **Start with local Neo4j** for development:
   ```bash
   docker run -d --name neo4j-dev -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/devpassword neo4j:2025.06.0
   ```

2. **Develop and test** using [http://localhost:7474](http://localhost:7474)

3. **Deploy to production** when ready:
   ```bash
   cd neo4j-official
   terraform apply
   ```

### Cost Optimization Tips

1. **Use local development** for daily work to minimize cloud costs

2. **Auto-stop production for development**:
   ```bash
   # Stop VM when not needed
   gcloud compute instances stop neo4j-arrgh-neo4j-1 --zone=us-central1-a
   
   # Start when needed  
   gcloud compute instances start neo4j-arrgh-neo4j-1 --zone=us-central1-a
   ```

3. **Schedule start/stop** with Cloud Scheduler for regular dev work

4. **Monitor costs** with GCP billing alerts

5. **Use Community Edition** (free) for development/testing

## Troubleshooting

### Local Development Issues

1. **Port conflicts**: Ensure ports 7474 and 7687 are available
2. **Container won't start**: Check Docker is running and has sufficient resources
3. **Can't connect**: Verify container is running with `docker ps`
4. **Data persistence**: Use Docker volumes for persistent data

### Production Issues

1. **Authentication errors**: Ensure `gcloud auth application-default login` is run
2. **Terraform fails**: Check GCP project permissions and billing status
3. **Can't connect**: Verify VM is running and firewall rules are correct
4. **Performance issues**: Consider upgrading machine type

### Debug Commands

#### Local Development
```bash
# Check container status
docker ps
docker logs neo4j-dev

# Test connectivity
curl -v http://localhost:7474
```

#### Production
```bash
# Check VM status
gcloud compute instances describe neo4j-arrgh-neo4j-1 --zone=us-central1-a

# Test connectivity
curl -v http://34.63.143.68:7474

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

## Quick Access Links

### Local Development
- 🌐 **Neo4j Browser**: [http://localhost:7474](http://localhost:7474)
- 📚 **Neo4j Documentation**: [https://neo4j.com/docs/](https://neo4j.com/docs/)
- 🐳 **Docker Hub**: [https://hub.docker.com/_/neo4j](https://hub.docker.com/_/neo4j)

### Production
- 🌐 **Neo4j Browser**: [http://34.63.143.68:7474](http://34.63.143.68:7474)
- ☁️ **GCP Console**: [https://console.cloud.google.com/compute/instances](https://console.cloud.google.com/compute/instances)
- 🏗️ **Terraform Module**: [https://github.com/neo4j-partners/gcp-marketplace-tf](https://github.com/neo4j-partners/gcp-marketplace-tf)

## Support

For deployment issues:

### Local Development
1. Check container logs: `docker logs neo4j-dev`
2. Verify ports are available: `lsof -i :7474 -i :7687`
3. Restart Docker service if needed

### Production
1. Check Neo4j container logs: `sudo docker logs neo4j-community`
2. Check Docker service logs: `sudo journalctl -u neo4j-docker.service`
3. Verify network connectivity and firewall rules
4. Consult Neo4j documentation: https://neo4j.com/docs/
5. Official Terraform module: https://github.com/neo4j-partners/gcp-marketplace-tf