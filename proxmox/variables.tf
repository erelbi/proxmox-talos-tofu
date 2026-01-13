variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_target_node" {
  type = string
}

variable "proxmox_storage_device" {
  type = string
}

variable "talos_version" {
  type    = string
  default = "1.12.1"
}

variable "kubernetes_version" {
  type    = string
  default = "1.35.0"
}


variable "pod_cidr" {
  description = "Kubernetes Pod ağ aralığı"
  type        = string
  default     = "10.233.0.0/16"
}



variable "service_cidr" {
  description = "Kubernetes Servis ağ aralığı"
  type        = string
  default     = "10.96.0.0/16"
}

variable "talos_linux_iso_image_url" {
  description = "URL of the Talos ISO image for initially booting the VM"
  type        = string
  default     = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.12.1/openstack-amd64.iso"
}

variable "talos_linux_iso_image_filename" {
  description = "Filename of the Talos ISO image for initially booting the VM"
  type        = string
  default     = "talos-linux-v1.11.6-qemu-guest-agent-amd64.iso"
}

variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "talos"
}

variable "cluster_vip_shared_ip" {
  description = "Shared virtual IP address for control plane nodes"
  type        = string
  default     = "192.168.134.10"
}

variable "node_data" {
  description = "A map of node data"
  type = object({
    controlplanes = map(object({
      install_disk  = string
      install_image = string
      hostname      = optional(string)
    }))
    workers = map(object({
      install_disk  = string
      install_image = string
      hostname      = optional(string)
    }))
  })
  default = {
    controlplanes = {
      "192.168.134.11" = {
        install_disk  = "/dev/vda"
        install_image = "factory.talos.dev/openstack-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.12.1"
      },
    }
    workers = {
      "192.168.134.20" = {
        install_disk  = "/dev/vda"
        install_image = "factory.talos.dev/openstack-installer/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515:v1.12.1"
      },
    }
  }
}

variable "network" {
  description = "Network for all nodes"
  type        = string
  default     = "192.168.134.0/24"
}

variable "network_gateway" {
  description = "Network gateway for all nodes"
  type        = string
  default     = "192.168.134.1"
}

variable "domain_name_server" {
  description = "DNS for all nodes"
  type        = string
  default     = "1.1.1.1"
}

variable "vlan_tag" {
  description = "Vlan tag for all nodes, default does not configure a Vlan"
  type        = number
  default     = 670
}

