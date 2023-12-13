variable docker_login_token {}
variable rootpass {}
variable username {
  type = string
  default = "remo"
}
variable vm-name {
 default = "rocky-tf-22.04"
}
variable vm_count {
  type = number
  default = 1
}
variable public_key_file_path {
  default = "/root/.ssh/id_rsa.pub"
}
variable phone_home_url {
  type    = string
  default = ""
}

variable disksize {
  type = number
  default = "70866960384"
}
  # cal from terraform console = "66 * 1024 * 1024 * 1024"
  # 66GiB. the root FS is automatically resized by cloud-init growpart (see https://cloudinit.readthedocs.io/en/latest/topics/examples.html#grow-partitions).
