terraform {

  required_version = ">= 0.13.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.11"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.7.1"
    }
  }
}

data "sops_file" "proxmox_secrets" {
  source_file = "secret.sops.yaml"
}

provider "proxmox" {
  pm_api_url          = data.sops_file.proxmox_secrets.data["proxmox_api_url"]
  pm_api_token_id     = data.sops_file.proxmox_secrets.data["proxmox_api_token_id"]
  pm_api_token_secret = data.sops_file.proxmox_secrets.data["proxmox_api_token_secret"]
  # (Optional) Skip TLS Verification
  pm_tls_insecure = true
  pm_parallel     = 20
  # Logging
  # pm_log_enable = true
  # pm_log_file = "terraform-plugin-proxmox.log"
  # pm_debug = true
  # pm_log_levels = {
  #   _default = "debug"
  #   _capturelog = ""
  # }
}

locals {
  ip0 = element(split(".", element(split("/", data.sops_file.proxmox_secrets.data["proxmox_vm_ip_start"]), 0)), 0)
  ip1 = element(split(".", element(split("/", data.sops_file.proxmox_secrets.data["proxmox_vm_ip_start"]), 0)), 1)
  ip2 = element(split(".", element(split("/", data.sops_file.proxmox_secrets.data["proxmox_vm_ip_start"]), 0)), 2)
  ip3 = tonumber(element(split(".", element(split("/", data.sops_file.proxmox_secrets.data["proxmox_vm_ip_start"]), 0)), 3))
}

resource "proxmox_vm_qemu" "k3s-vm" {

  # VM General Settings
  count       = length(split(",", data.sops_file.proxmox_secrets.data["proxmox_vms"])) # length(var.hostnames)
  target_node = element(split(":", element(split(",", data.sops_file.proxmox_secrets.data["proxmox_vms"]), count.index)), 1)
  vmid        = data.sops_file.proxmox_secrets.data["proxmox_vm_start_id"] + count.index # var.vmid + count.index
  name        = element(split(":", element(split(",", data.sops_file.proxmox_secrets.data["proxmox_vms"]), count.index)), 0)

  # VM Advanced General Settings
  onboot = true

  # VM OS Settings
  full_clone = true
  clone      = data.sops_file.proxmox_secrets.data["proxmox_vm_template_name"] # "template-fedora"

  # VM CPU Settings
  cores   = data.sops_file.proxmox_secrets.data["proxmox_vm_cores"]
  sockets = data.sops_file.proxmox_secrets.data["proxmox_vm_sockets"]
  cpu     = "host"

  # VM Memory Settings
  memory = data.sops_file.proxmox_secrets.data["proxmox_vm_memory"]

  disk {
    type    = "scsi"
    size    = data.sops_file.proxmox_secrets.data["proxmox_vm_disk_size"] # "4G"
    storage = data.sops_file.proxmox_secrets.data["proxmox_vm_storage"]   # "local-lvm"
  }
  # VM Network Settings
  network {
    bridge = data.sops_file.proxmox_secrets.data["proxmox_vm_network_bridge"] # "vmbr0"
    model  = "virtio"
  }

  # VM Cloud-Init Settings
  os_type = "cloud-init"

  # (Optional) IP Address and Gateway
  ipconfig0    = "ip=${local.ip0}.${local.ip1}.${local.ip2}.${local.ip3 + count.index}/${element(split("/", data.sops_file.proxmox_secrets.data["proxmox_vm_ip_start"]), 1)},gw=${data.sops_file.proxmox_secrets.data["proxmox_vm_ip_gw"]}"
  nameserver   = data.sops_file.proxmox_secrets.data["proxmox_vm_ip_dns"]
  searchdomain = data.sops_file.proxmox_secrets.data["proxmox_vm_searchdomain"]
  # (Optional) Default User
  ciuser     = data.sops_file.proxmox_secrets.data["proxmox_vm_user"]
  cipassword = data.sops_file.proxmox_secrets.data["proxmox_vm_password"]

  # (Optional) Add your SSH KEY
  #sshkeys = file(data.sops_file.proxmox_secrets.data["proxmox_vm_ssh_pubkey"])
  sshkeys = data.sops_file.proxmox_secrets.data["proxmox_vm_ssh_pubkey"]
  # Enable Qemu guest agent
  agent = 1
}
