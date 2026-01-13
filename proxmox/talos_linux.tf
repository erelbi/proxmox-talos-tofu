resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_vip_shared_ip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_vip_shared_ip}:6443"
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = concat([var.cluster_vip_shared_ip], [for k, v in var.node_data.controlplanes : k])
}

resource "talos_machine_configuration_apply" "controlplane" {
  depends_on                  = [proxmox_vm_qemu.kubernetes_control_plane]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  for_each                    = var.node_data.controlplanes
  node                        = each.key
  config_patches = [
    templatefile("${path.module}/templates/machine_config_patches_controlplane.tftpl", {
      hostname             = each.value.hostname == null ? format("%s-cp-%s", var.cluster_name, index(keys(var.node_data.controlplanes), each.key)) : each.value.hostname
      install_disk         = each.value.install_disk
      install_image        = each.value.install_image
      dns                  = var.domain_name_server
      ip_address           = "${each.key}/24"
      network              = var.network
      network_gateway      = var.network_gateway
      pod_cidr             = var.pod_cidr
      service_cidr         = var.service_cidr
      vip_shared_ip        = var.cluster_vip_shared_ip
      gateway_api_manifest = file("${path.module}/gateway-api/gateway-api-crds-v1.3.yaml")
      flux_manifest        = file("${path.module}/flux/mgm.yaml")
      cilium_manifest      = data.helm_template.cilium.manifest
    }),
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on                  = [proxmox_vm_qemu.kubernetes_worker]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  for_each                    = var.node_data.workers
  node                        = each.key
  config_patches = [
    templatefile("${path.module}/templates/machine_config_patches_worker.tftpl", {
      hostname        = each.value.hostname == null ? format("%s-worker-%s", var.cluster_name, index(keys(var.node_data.workers), each.key)) : each.value.hostname
      install_disk    = each.value.install_disk
      install_image   = each.value.install_image
      dns             = var.domain_name_server
      pod_cidr        = var.pod_cidr
      service_cidr    = var.service_cidr
      ip_address      = "${each.key}/24"
      network         = var.network
      network_gateway = var.network_gateway
    })
  ]
}



resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : k][0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : k][0]
  endpoint             = var.cluster_vip_shared_ip
}




resource "null_resource" "setup_node_local_dns" {
  depends_on = [
    talos_cluster_kubeconfig.this
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "${talos_cluster_kubeconfig.this.kubeconfig_raw}" > ${path.module}/kubeconfig_temp
      export KUBECONFIG=${path.module}/kubeconfig_temp
      KUBECTL_PATH="/usr/local/bin/kubectl"


      if [ ! -f "$KUBECTL_PATH" ]; then
          echo "HATA: $KUBECTL_PATH bulunamadı."
          exit 1
      fi

      wget -q https://raw.githubusercontent.com/cilium/cilium/1.18.5/examples/kubernetes-local-redirect/node-local-dns.yaml -O node-local-dns-tmp.yaml
      
      KUBEDNS=""
      echo "kube-dns IP bekleniyor (Max 5 dakika)..."
      

      for i in $(seq 1 30); do
        KUBEDNS=$($KUBECTL_PATH get svc kube-dns -n kube-system -o jsonpath={.spec.clusterIP} 2>/dev/null)
        if [ ! -z "$KUBEDNS" ]; then 
            echo "kube-dns IP bulundu: $KUBEDNS"
            break 
        fi
        echo "Deneme $i/30: Servis henüz hazır değil, 10sn bekleniyor..."
        sleep 10
      done

      if [ -z "$KUBEDNS" ]; then
        echo "HATA: 5 dakika sonunda kube-dns servisi bulunamadı."
        exit 1
      fi

      if [ -z "$KUBEDNS" ]; then
        echo "HATA: kube-dns servisi bulunamadı."
        exit 1
      fi

      sed -i "s/__PILLAR__DNS__SERVER__/$KUBEDNS/g" node-local-dns-tmp.yaml

      kubectl apply -f node-local-dns-tmp.yaml
      kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.18.5/examples/kubernetes-local-redirect/node-local-dns-lrp.yaml

      rm node-local-dns-tmp.yaml kubeconfig_temp
    EOT
  }

  triggers = {
    cluster_id = talos_cluster_kubeconfig.this.id
  }
}
