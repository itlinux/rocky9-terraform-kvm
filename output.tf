output password {
  value = random_string.password.result
}
output sha512_hash {
  value = htpasswd_password.hash.sha512
}

# this does not work as desired
#output "ip" {
#  value = libvirt_domain.rocky_instance[*].network_interface.0.addresses
#}

