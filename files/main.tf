terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# variable "yandex_cloud_token" {
#   type = string
# }

provider "yandex" {
#   token = var.yandex_cloud_token
#   cloud_id = "b1g0togg4o2vkjsh19cb"
#   folder_id = "b1gvu5e8c9o1aurrrcr3"
  zone = "ru-central1-a"
}

resource "yandex_compute_instance" "vm" {
  count = 2
  name = "vm${count.index}"
  platform_id = "standard-v3"
  zone = "ru-central1-a"
  boot_disk {
    initialize_params {
	  image_id = "fd8dmsb2cgoabg4qelih"
	  size = 10
    }
  }

  resources {
	core_fraction = 20
	cores = 2
	memory = 2
   }

  network_interface {
	subnet_id = yandex_vpc_subnet.subnet-1.id
	nat = true
  }

  scheduling_policy {
    preemptible = true
  }

  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

resource "yandex_vpc_network" "network-1" {
name = "network-1"
}

resource "yandex_vpc_subnet" "subnet-1" {
	name = "subnet1"
	zone = "ru-central1-a"
	v4_cidr_blocks = ["192.168.10.0/24"]
	network_id = "${yandex_vpc_network.network-1.id}"
}

resource "yandex_lb_target_group" "otkaz-1" {
  name      = "otkaz-1"
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.vm[0].network_interface.0.ip_address
  }
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.vm[1].network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "load-balance" {
  name = "load-balance" # имя балансровщика
  deletion_protection = "false"
  listener {
    name = "my-load-balancer"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.otkaz-1.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
