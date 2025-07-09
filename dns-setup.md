# DNS Setup for neo4j.paulbonneville.com

## Required DNS Records

To configure the custom domain `neo4j.paulbonneville.com`, you need to add the following DNS records to your domain registrar or DNS provider:

### A Record
```
Name: neo4j.paulbonneville.com
Type: A
Value: 130.211.30.22
TTL: 300 (or your preferred TTL)
```

### Alternative CNAME Record (if using subdomain)
```
Name: neo4j
Type: CNAME
Value: neo4j.paulbonneville.com.
TTL: 300
```

## DNS Provider Instructions

### If using Google Cloud DNS:
```bash
# Create DNS zone (if not exists)
gcloud dns managed-zones create paulbonneville-com-zone \
    --dns-name="paulbonneville.com." \
    --description="DNS zone for paulbonneville.com"

# Add A record for neo4j subdomain
gcloud dns record-sets transaction start --zone=paulbonneville-com-zone
gcloud dns record-sets transaction add 130.211.30.22 \
    --name=neo4j.paulbonneville.com. \
    --ttl=300 \
    --type=A \
    --zone=paulbonneville-com-zone
gcloud dns record-sets transaction execute --zone=paulbonneville-com-zone
```

### If using Cloudflare:
1. Log into Cloudflare dashboard
2. Select your domain `paulbonneville.com`
3. Go to DNS > Records
4. Add A record:
   - Name: `neo4j`
   - IPv4 address: `130.211.30.22`
   - Proxy status: DNS only (turn off proxy for now)
   - TTL: Auto

### If using other DNS providers:
1. Access your DNS management panel
2. Add A record pointing `neo4j.paulbonneville.com` to `130.211.30.22`
3. Set TTL to 300 seconds (5 minutes)

## Verification

After adding the DNS records, verify they're working:

### Check DNS propagation:
```bash
# Test DNS resolution
nslookup neo4j.paulbonneville.com
dig neo4j.paulbonneville.com

# Test from different locations
curl -I https://neo4j.paulbonneville.com
```

### Expected output:
```
neo4j.paulbonneville.com.	300	IN	A	130.211.30.22
```

## SSL Certificate Provisioning

The SSL certificate will be automatically provisioned by Google Cloud once:

1. DNS records are properly configured
2. The load balancer is deployed
3. The domain resolves to the correct IP address

### Check certificate status:
```bash
# After terraform apply
terraform output ssl_certificate_status
```

### Certificate states:
- `PROVISIONING`: Certificate is being created
- `ACTIVE`: Certificate is ready and serving traffic
- `FAILED`: Certificate provisioning failed (check DNS)

## Timeline

- **DNS propagation**: 5-60 minutes
- **SSL certificate provisioning**: 10-60 minutes
- **Total setup time**: 15-120 minutes

## Troubleshooting

### DNS not resolving:
1. Verify A record points to `130.211.30.22`
2. Check TTL settings (lower is better for testing)
3. Wait for DNS propagation
4. Test from different locations/devices

### SSL certificate not provisioning:
1. Ensure DNS is resolving correctly
2. Check load balancer is deployed
3. Verify domain ownership
4. Wait up to 60 minutes for auto-provisioning

### Domain not accessible:
1. Check firewall rules allow port 80/443
2. Verify load balancer health checks are passing
3. Ensure Neo4j instances are running
4. Check backend service configuration

## Next Steps

1. **Add DNS records** using one of the methods above
2. **Deploy load balancer** with `terraform apply`
3. **Wait for SSL certificate** to provision
4. **Test the domain** at https://neo4j.paulbonneville.com
5. **Update applications** to use the custom domain

## Security Considerations

- SSL certificate is managed by Google Cloud
- HTTPS redirect is automatically configured
- HTTP traffic is redirected to HTTPS
- Certificate auto-renews before expiration