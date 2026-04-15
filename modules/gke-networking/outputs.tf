output "vpc_id" {
  description = "VPC 網路的唯一識別碼"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "VPC 網路名稱"
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "子網的唯一識別碼"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "子網名稱"
  value       = google_compute_subnetwork.subnet.name
}

output "static_ip" {
  description = "該環境對應的全球靜態 IP 地址"
  value       = google_compute_global_address.ingress_ip.address
}