terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Service account for Neo4j VM
resource "google_service_account" "neo4j_service_account" {
  account_id   = "neo4j-vm-sa"
  display_name = "Neo4j VM Service Account"
  description  = "Service account for Neo4j VM instance"
}

# IAM roles for service account
resource "google_project_iam_member" "neo4j_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.neo4j_service_account.email}"
}

resource "google_project_iam_member" "neo4j_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.neo4j_service_account.email}"
}

resource "google_project_iam_member" "neo4j_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.neo4j_service_account.email}"
}

# Firewall rules for Neo4j
resource "google_compute_firewall" "neo4j_http" {
  name    = "neo4j-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["7474"]
  }

  source_ranges = var.allow_source_ranges
  target_tags   = var.network_tags
  
  description = "Allow HTTP access to Neo4j browser"
}

resource "google_compute_firewall" "neo4j_bolt" {
  name    = "neo4j-bolt"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["7687"]
  }

  source_ranges = var.allow_source_ranges
  target_tags   = var.network_tags
  
  description = "Allow Bolt access to Neo4j database"
}

# Firewall rule for SSH access
resource "google_compute_firewall" "neo4j_ssh" {
  name    = "neo4j-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = var.network_tags
  
  description = "Allow SSH access to Neo4j VM"
}

# Startup script for VM
locals {
  startup_script = <<-EOF
    #!/bin/bash
    
    # Update system
    apt-get update
    apt-get install -y curl wget gnupg lsb-release
    
    # Install Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Configure Docker to start on boot
    systemctl enable docker
    systemctl start docker
    
    # Add neo4j user to docker group
    useradd -m -s /bin/bash neo4j
    usermod -aG docker neo4j
    
    # Create neo4j directories
    mkdir -p /opt/neo4j/{data,logs,config,import}
    chown -R neo4j:neo4j /opt/neo4j
    
    # Create docker-compose.yml
    cat > /opt/neo4j/docker-compose.yml << 'DOCKER_COMPOSE_EOF'
version: '3.8'

services:
  neo4j:
    image: neo4j:5.15-community
    container_name: arrgh-neo4j
    restart: unless-stopped
    
    environment:
      - NEO4J_AUTH=neo4j/${var.neo4j_password}
      - NEO4J_server_memory_heap_initial__size=256m
      - NEO4J_server_memory_heap_max__size=512m
      - NEO4J_server_memory_pagecache_size=256m
      - NEO4J_server_default__listen__address=0.0.0.0
      - NEO4J_server_default__database=neo4j
      - NEO4J_server_db_logs_query_enabled=INFO
      - NEO4J_server_http_enabled=true
      - NEO4J_server_https_enabled=false
      - NEO4J_server_bolt_enabled=true
      - NEO4J_server_db_transaction_timeout=30s
      - NEO4J_server_db_lock_acquisition_timeout=20s
      - NEO4J_server_logs_user_level=INFO
      - NEO4J_server_logs_security_level=INFO
    
    volumes:
      - ./data:/data
      - ./logs:/logs
      - ./import:/var/lib/neo4j/import
    
    ports:
      - "7474:7474"
      - "7687:7687"
    
    healthcheck:
      test: ["CMD-SHELL", "cypher-shell -u neo4j -p ${var.neo4j_password} 'RETURN 1;' || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    deploy:
      resources:
        limits:
          memory: 768M
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
DOCKER_COMPOSE_EOF
    
    # Create startup script
    cat > /opt/neo4j/start.sh << 'START_SCRIPT_EOF'
#!/bin/bash
cd /opt/neo4j
docker-compose up -d
START_SCRIPT_EOF
    
    chmod +x /opt/neo4j/start.sh
    chown neo4j:neo4j /opt/neo4j/start.sh
    
    # Create systemd service for Neo4j
    cat > /etc/systemd/system/neo4j-docker.service << 'SERVICE_EOF'
[Unit]
Description=Neo4j Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/neo4j
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=neo4j
Group=neo4j

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    
    # Enable and start Neo4j service
    systemctl daemon-reload
    systemctl enable neo4j-docker.service
    systemctl start neo4j-docker.service
    
    # Install monitoring tools
    apt-get install -y htop iotop
    
    # Create log rotation for Docker logs
    cat > /etc/logrotate.d/docker << 'LOGROTATE_EOF'
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
LOGROTATE_EOF
    
    # Setup CloudWatch monitoring (optional)
    if [ "${var.enable_monitoring}" = "true" ]; then
        curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
        dpkg -i amazon-cloudwatch-agent.deb
    fi
    
    echo "Neo4j VM setup completed successfully" | logger -t neo4j-setup
  EOF
}

# VM instance
resource "google_compute_instance" "neo4j_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  
  tags = var.network_tags
  
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  
  network_interface {
    network = "default"
    access_config {
      # Ephemeral external IP
    }
  }
  
  service_account {
    email  = google_service_account.neo4j_service_account.email
    scopes = ["cloud-platform"]
  }
  
  metadata = {
    ssh-keys = "neo4j:${file("~/.ssh/id_rsa.pub")}"
  }
  
  metadata_startup_script = local.startup_script
  
  # Allow stopping for maintenance
  allow_stopping_for_update = true
  
  labels = {
    environment = "production"
    service     = "neo4j"
    managed_by  = "terraform"
  }
}

# Static IP reservation (optional)
resource "google_compute_address" "neo4j_static_ip" {
  name   = "neo4j-static-ip"
  region = var.region
}

# Attach static IP to VM
resource "google_compute_instance" "neo4j_vm_with_static_ip" {
  count = 0  # Disabled by default to save costs
  
  name         = "${var.vm_name}-static"
  machine_type = var.machine_type
  zone         = var.zone
  
  tags = var.network_tags
  
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size
      type  = var.disk_type
    }
  }
  
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.neo4j_static_ip.address
    }
  }
  
  service_account {
    email  = google_service_account.neo4j_service_account.email
    scopes = ["cloud-platform"]
  }
  
  metadata_startup_script = local.startup_script
  
  allow_stopping_for_update = true
}