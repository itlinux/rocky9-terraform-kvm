resource random_string password {
  length = 6
}
resource htpasswd_password hash {
  password = random_string.password.result
}
#
# export LIBVIRT_DEFAULT_URI="qemu+ssh://root@192.168.1.100/system"
# the user must be a member of the libvirt group on the kvm server
# and the security_driver must be adjusted as per
# https://github.com/dmacvicar/terraform-provider-libvirt/issues/546#issuecomment-612983090
#
provider "libvirt" {
  uri = "qemu:///system"
  # Configuration options
}

# this resource does not create a network bridge
# it only configures kvm to be aware of an existing
# network bridge
resource libvirt_network bridge {
  name      = "rocky-kvmbridge"
  mode      = "bridge"
  bridge    = "bond-br"
  #autostart = true
}

# at the end of the cloudinit
# add the following line to /etc/nginx/nginx.conf
# load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;
# ideally after "include /etc/nginx/modules-enabled/*.conf;"
# sed is probably the best option

resource "libvirt_cloudinit_disk" "simple_cloud_init" {
  count = var.vm_count
  name      = format("simple_cloud_init%02d",count.index)
  pool      = "images"
  user_data = <<EOF
#cloud-config
hostname: ${format("${var.vm-name}-%02d",count.index)}
fqdn: ${format("${var.vm-name}-%02d.local",count.index)}
yum_repos:
  # The name of the repository
  epel-testing:
    # Any repository configuration options
    # See: man yum.conf
    #
    # This one is required!
    baseurl: https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/
    enabled: true
    failovermethod: priority
    gpgcheck: false
    gpgkey: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9-Testing
    name: Extra Packages for Enterprise Linux 9 - Testing
packages:
  - ca-certificates
  - curl
  - gnupg
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
write_files:
  -  dnf install -y httpd-tools cloud-utils-growpart gdisk libicu
users:
  - name: remo
    passwd: ${htpasswd_password.hash.sha512}
    lock_passwd: false
    ssh-authorized-keys:
      - ${jsonencode(trimspace(file(var.public_key_file_path)))}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_import_id:
      - gh:${var.username}
  - name: root
    ssh-authorized-keys:
      - ${jsonencode(trimspace(file(var.public_key_file_path)))}
ssh_pwauth: True
chpasswd:
  list: |
     root:${var.rootpass}
  expire: False
runcmd:
  - ip a s ens3|grep inet| awk '{print $2}' |tee /etc/issue
  - dnf install -y httpd-tools cloud-utils-growpart gdisk libicu git wget net-tools httpd-tools htop epel-release htop
EOF
}

resource libvirt_volume rocky_base {
  name   = "rocky_base_terraform"
  source = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base-9.3-20231113.0.x86_64.qcow2"
  pool   = "images"
}
resource libvirt_volume rocky_instance {
  count          = var.vm_count
  name           = format("rocky-instance-%02d",count.index)
  base_volume_id = libvirt_volume.rocky_base.id
  size           = var.disksize
  pool           = "images"
}

# Define KVM domain to create
resource "libvirt_domain" "rocky_instance" {
  count  = var.vm_count
  name   = format("${var.vm-name}-%02d",count.index)
  memory = 4096
  vcpu   = 2

  network_interface {
    network_name = libvirt_network.bridge.name # List networks with virsh net-list
  }

  cloudinit = libvirt_cloudinit_disk.simple_cloud_init[count.index].id

  disk {
    volume_id = libvirt_volume.rocky_instance[count.index].id
  }

  cpu {
    mode = "host-passthrough"
  }

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}
