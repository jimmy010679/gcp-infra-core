output "instance_name" {
  description = "跳板機 VM 的名稱"
  value       = google_compute_instance.bastion.name
}

output "instance_self_link" {
  description = "跳板機 VM 的 Self Link"
  value       = google_compute_instance.bastion.self_link
}

output "instance_internal_ip" {
  description = "跳板機 VM 的內部 IP 地址"
  value       = google_compute_instance.bastion.network_interface[0].network_ip
}