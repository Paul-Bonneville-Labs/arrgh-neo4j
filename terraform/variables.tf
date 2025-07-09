variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "VM instance name"
  type        = string
  default     = "arrgh-neo4j"
}

variable "machine_type" {
  description = "Machine type for Neo4j VM"
  type        = string
  default     = "e2-micro"
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-standard"
}

variable "neo4j_password" {
  description = "Neo4j database password"
  type        = string
  sensitive   = true
}

variable "enable_monitoring" {
  description = "Enable monitoring and logging"
  type        = bool
  default     = true
}

variable "network_tags" {
  description = "Network tags for firewall rules"
  type        = list(string)
  default     = ["neo4j-server"]
}

variable "allow_source_ranges" {
  description = "Source IP ranges allowed to access Neo4j"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}