output "load_balancer_ip" {
  description = "Load Balancer 的外部靜態 IP"
  value       = var.enable_vm_infrastructure ? google_compute_global_address.vm_lb_ip[0].address : null
}