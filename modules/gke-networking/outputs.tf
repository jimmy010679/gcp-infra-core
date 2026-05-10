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

output "nat_name" {
  description = "Cloud NAT 名稱"
  value = google_compute_router_nat.nat.name
}

output "vpc_network_id" {
  description = "VPC 網路的完整 ID (Self Link 或 Resource ID)"
  value       = google_compute_network.vpc.id
}

output "nat_ip_count" {
  value = var.nat_ip_count
  description = "傳出 Cloud NAT 所使用的靜態 IP 數量，供監控告警計算閾值"
}