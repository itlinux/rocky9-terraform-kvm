terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.7.6"
    }
    htpasswd = {
      source = "loafoe/htpasswd"
      version = "1.0.4"
    }
  }
}
