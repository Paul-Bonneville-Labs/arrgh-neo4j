# Neo4j Community Edition on Google Cloud Platform

This project deploys Neo4j Community Edition on Google Cloud Platform using an e2-micro VM instance within the GCP free tier. It uses Docker containers for easy deployment and management.

## Overview

- **VM Type**: e2-micro (1GB RAM, 0.25 vCPU)
- **Storage**: 30GB persistent disk
- **Cost**: Fits within GCP free tier limits
- **Neo4j Version**: 5.15 Community Edition
- **Deployment**: Docker Compose with Terraform

## Prerequisites

- Google Cloud SDK (`gcloud`) installed and authenticated
- Terraform >= 1.0 installed
- SSH key pair at `~/.ssh/id_rsa` (will be generated if not present)
- `jq` command-line JSON processor

## Quick Start

1. **Configure your deployment**:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   # Edit terraform.tfvars with your GCP project ID and Neo4j password
   ```

2. **Deploy the VM**:
   ```bash
   ./scripts/deploy-vm.sh
   ```

3. **Check status**:
   ```bash
   ./scripts/status-neo4j.sh
   ```

4. **Access Neo4j**:
   - Open the HTTP browser URL shown in the deployment output
   - Use username `neo4j` and the password from your `terraform.tfvars`

## Management Scripts

### Deployment and Lifecycle

- **`deploy-vm.sh`** - Deploy Neo4j VM with all resources
- **`destroy-vm.sh`** - Completely remove all resources
- **`status-neo4j.sh`** - Check VM and Neo4j status
- **`start-neo4j.sh`** - Start Neo4j service and VM if needed
- **`stop-neo4j.sh`** - Stop Neo4j service and optionally VM

### Maintenance

- **`backup-neo4j.sh`** - Create and optionally download backups
- **`backup-neo4j.sh list`** - List available backups
- **`backup-neo4j.sh cleanup`** - Remove old backups (keep last 5)

## Configuration

### Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
# Required
project_id = "your-gcp-project-id"
neo4j_password = "your-secure-password"

# Optional
region = "us-central1"
zone = "us-central1-a"
vm_name = "arrgh-neo4j"
machine_type = "e2-micro"
disk_size = 30
disk_type = "pd-standard"
```

### Neo4j Configuration

The Neo4j instance is optimized for 1GB RAM:

- **Heap**: 256MB initial, 512MB maximum
- **Page Cache**: 256MB
- **Memory Limits**: 768MB container limit
- **CPU Limits**: 0.5 CPU with 0.25 reserved

Configuration is located in:
- `config/neo4j.conf` - Neo4j server configuration
- `docker-compose.yml` - Docker container settings

## Network Security

The deployment creates firewall rules for:
- **SSH (22)**: Access from anywhere (for management)
- **HTTP (7474)**: Neo4j browser interface
- **Bolt (7687)**: Neo4j database protocol

By default, Neo4j ports are open to all IPs. To restrict access, modify the `allow_source_ranges` in `terraform.tfvars`:

```hcl
allow_source_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
```

## Monitoring and Maintenance

### System Resources

Check resource usage:
```bash
./scripts/status-neo4j.sh
```

### Logs

View recent logs:
```bash
./scripts/status-neo4j.sh --logs
```

### Backups

Create regular backups:
```bash
./scripts/backup-neo4j.sh
```

Set up automated backups with cron:
```bash
# Add to crontab for daily backups at 2 AM
0 2 * * * /path/to/arrgh-neo4j/scripts/backup-neo4j.sh
```

## Integration with arrgh-fastapi

Update your `arrgh-fastapi` configuration to connect to the new Neo4j instance:

```python
# In your .env.local file
NEO4J_URI=neo4j://YOUR_VM_IP:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=your-secure-password
```

The VM IP address can be found in the deployment output or by running:
```bash
cd terraform && terraform output vm_external_ip
```

## Troubleshooting

### Common Issues

1. **VM won't start**: Check GCP quotas and billing
2. **SSH connection fails**: Verify firewall rules and SSH keys
3. **Neo4j won't start**: Check logs and memory limits
4. **Connection timeouts**: Verify firewall rules and network settings

### Debug Commands

```bash
# SSH into the VM
ssh -i ~/.ssh/id_rsa neo4j@VM_IP

# Check Docker containers
docker ps
docker logs arrgh-neo4j

# Check Neo4j status
systemctl status neo4j-docker

# Check system resources
free -h
df -h
```

### Performance Optimization

For better performance with limited resources:

1. **Reduce concurrent connections** in Neo4j config
2. **Use smaller batch sizes** in your queries
3. **Optimize Cypher queries** for memory usage
4. **Consider upgrading** to e2-small if needed

## Cost Management

The e2-micro instance fits within GCP's free tier:
- **Always Free**: 1 e2-micro instance per month
- **Storage**: 30GB persistent disk
- **Network**: 1GB egress per month (free tier)

To minimize costs:
- Stop VM when not in use: `./scripts/stop-neo4j.sh`
- Use scheduled start/stop with Cloud Scheduler
- Monitor usage with Cloud Monitoring

## Contributing

When making changes:
1. Test with a separate Terraform workspace
2. Update documentation if needed
3. Test all scripts with different scenarios
4. Ensure backward compatibility

## Support

For issues:
1. Check the troubleshooting section
2. Review logs with `./scripts/status-neo4j.sh --logs`
3. Test connectivity with provided debug commands