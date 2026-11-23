output "network_name" {
  description = "Docker network created by Terraform and used by Compose."
  value       = docker_network.lab.name
}

output "network_id" {
  description = "Docker ID of the managed network."
  value       = docker_network.lab.id
}
