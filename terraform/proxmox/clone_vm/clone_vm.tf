provider "proxmox" {
  endpoint = "https://10.50.0.102:8006/api2/json"
  username = "root@pam"
  insecure = true
  ssh {
    agent    = true
    username = "root"
  }
}

resource "proxmox_virtual_environment_vm" "data_vm" {
  node_name = "pve1"
  started = false
  on_boot = false
  vm_id = 100

  cpu {
    cores = 1
    architecture  = "x86_64"
  }

  disk {
    file_format  = "raw"
    interface    = "scsi0"
    size         = 32
  }

  lifecycle {
    ignore_changes = [
      cpu["architecture"],
      disk
    ]
  }
}

resource "proxmox_virtual_environment_file" "cloud_network_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve1"

  source_raw {
    data = file("${path.module}/cloud-init/network_config.yml")
    file_name = "ci-network.yml"
  }
}

resource "proxmox_virtual_environment_file" "cloud_user_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve1"

  source_raw {
    data = file("${path.module}/cloud-init/user_data.yml")
    file_name = "ci-user.yml"
  }
}

resource "proxmox_virtual_environment_vm" "docker-host1" {
  name        = "docker-host1"
  description = "[Terraform] Docker Host"
  node_name = "pve1"
  vm_id = 101

  clone  {
    vm_id =  9999
  }

  agent {
    enabled = true
  }

  disk {
    size = 6
    interface = "scsi0"
    file_format = "raw"
    cache = "none"
  }

  # attached disks from data_vm
  dynamic "disk" {
    for_each = { for idx, val in proxmox_virtual_environment_vm.data_vm.disk : idx => val }
    iterator = data_disk
    content {
      datastore_id      = data_disk.value["datastore_id"]
      path_in_datastore = data_disk.value["path_in_datastore"]
      file_format       = data_disk.value["file_format"]
      size              = data_disk.value["size"]
      # assign from scsi1 and up
      interface         = "scsi${data_disk.key + 1}"
    }
  }

  network_device {
    bridge = "vmbr0"
    mac_address = "00:50:56:00:01:01"
  }

  network_device {
    bridge = "vmbr0"
    mac_address = "00:50:56:00:01:02"
    vlan_id = 100
  }

  operating_system {
    type = "l26"
  }

  cpu {
    type = "host"
  }

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  memory {
    dedicated = 8092
  }

  initialization {
    network_data_file_id = proxmox_virtual_environment_file.cloud_network_config.id
    user_data_file_id    = proxmox_virtual_environment_file.cloud_user_config.id
  }

  lifecycle {
    ignore_changes = [network_device,disk]
  }
}
