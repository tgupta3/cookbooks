terraform {
  cloud {
    organization = "tushar_home"

    workspaces {
      name = "clone-vm"
    }
  }

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }

  required_version = ">= 1.1.0"
}