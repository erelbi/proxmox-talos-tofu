resource "helm_release" "cilium_lb_config" {
  depends_on = [helm_release.argocd]
  name       = "cilium-lb-config"
  chart      = "${path.module}/helm_charts/cilium-lb-config"
  timeout    = 60
  set = [
    {
      name  = "ciliumLoadBalancerIpRange.start"
      value = var.cilium_load_balancer_ip_range_start
    },
    {
      name  = "ciliumLoadBalancerIpRange.stop"
      value = var.cilium_load_balancer_ip_range_stop
    },
  ]
}
