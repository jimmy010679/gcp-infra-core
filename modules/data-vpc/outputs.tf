output "vpc_id" {
  value = google_compute_network.data_vpc.id
}

output "vpc_network_id" {
  value = google_compute_network.data_vpc.id
}

output "subnet_id" {
  description = "子網的唯一識別碼"
  value = google_compute_subnetwork.data_subnet.id
}

output "network_name" {
  value = google_compute_network.data_vpc.name
}