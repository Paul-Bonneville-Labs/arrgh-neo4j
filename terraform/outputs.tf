output "vm_external_ip" {
  description = "External IP address of the Neo4j VM"
  value       = google_compute_instance.neo4j_vm.network_interface[0].access_config[0].nat_ip
}

output "vm_internal_ip" {
  description = "Internal IP address of the Neo4j VM"
  value       = google_compute_instance.neo4j_vm.network_interface[0].network_ip
}

output "vm_name" {
  description = "Name of the Neo4j VM instance"
  value       = google_compute_instance.neo4j_vm.name
}

output "vm_zone" {
  description = "Zone of the Neo4j VM instance"
  value       = google_compute_instance.neo4j_vm.zone
}

output "service_account_email" {
  description = "Email of the Neo4j VM service account"
  value       = google_service_account.neo4j_service_account.email
}

output "neo4j_http_url" {
  description = "Neo4j HTTP browser URL"
  value       = "http://${google_compute_instance.neo4j_vm.network_interface[0].access_config[0].nat_ip}:7474"
}

output "neo4j_bolt_url" {
  description = "Neo4j Bolt connection URL"
  value       = "neo4j://${google_compute_instance.neo4j_vm.network_interface[0].access_config[0].nat_ip}:7687"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh -i ~/.ssh/id_rsa neo4j@${google_compute_instance.neo4j_vm.network_interface[0].access_config[0].nat_ip}"
}

output "static_ip_address" {
  description = "Reserved static IP address"
  value       = google_compute_address.neo4j_static_ip.address
}

output "firewall_rules" {
  description = "Created firewall rules"
  value = {
    http = google_compute_firewall.neo4j_http.name
    bolt = google_compute_firewall.neo4j_bolt.name
    ssh  = google_compute_firewall.neo4j_ssh.name
  }
}

output "connection_info" {
  description = "Neo4j connection information for applications"
  value = {
    host     = google_compute_instance.neo4j_vm.network_interface[0].access_config[0].nat_ip
    http_port = 7474
    bolt_port = 7687
    username = "neo4j"
    database = "neo4j"
  }
  sensitive = false
}