
variable "credentials_file" { 
  default = "/home/cry8499/cis-91/cis-91-361922-286e86948aff.json" 
}

variable "project" {
  default = "cis-91-361922"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  region  = var.region
  zone    = var.zone 
  project = var.project
}

resource "google_compute_network" "vpc_network" {
  name = "cis91-network"
}

resource "google_compute_instance" "webservers" {
  count        = 3
  name         = "db${count.index}"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

  labels = {
    role: "web"
  }

  attached_disk {
    source = google_compute_disk.mediawiki.self_link
    device_name = "systemDisk"
  }

  attached_disk {
    source = google_compute_disk.mediawiki1.self_link
    device_name = "dataDisk"
  }
}

resource "google_compute_disk" "mediawiki" {
  name  = "mediawiki"
  type  = "pd-ssd"
  zone  = "us-central1-c"
  labels = {
    environment = "dev"
  }
  size = "16"
}

resource "google_compute_disk" "mediawiki1" {
  name  = "mediawiki1"
  type  = "pd-ssd"
  zone  = "us-central1-c"
  labels = {
    environment = "dev"
  }
  size = "16"
}

resource "google_compute_firewall" "default-firewall" {
  name = "default-firewall"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports = ["22", "80"]
  }
  source_ranges = ["0.0.0.0/0"]
}

#Health Check
resource "google_compute_health_check" "webservers" {
  name = "webserver-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    request_path = "/health.html"
    port = 80
  }
}

#Instance Group
resource "google_compute_instance_group" "webservers" {
  name        = "cis91-webservers"
  description = "Webserver instance group"

  instances = google_compute_instance.webservers[*].self_link

  named_port {
    name = "http"
    port = "80"
  }
}

#Backend Service
resource "google_compute_backend_service" "webservice" {
  name      = "web-service"
  port_name = "http"
  protocol  = "HTTP"

  backend {
    group = google_compute_instance_group.webservers.id
  }

  health_checks = [
    google_compute_health_check.webservers.id
  ]
}

#URL Map
resource "google_compute_url_map" "default" {
  name            = "my-site"
  default_service = google_compute_backend_service.webservice.id
}

#HTTP Proxy
resource "google_compute_target_http_proxy" "default" {
  name     = "web-proxy"
  url_map  = google_compute_url_map.default.id
}

#IP Address
resource "google_compute_global_address" "default" {
  name = "external-address"
}

#Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "forward-application"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
  ip_address            = google_compute_global_address.default.address
}

output "external-ip" {
  value = google_compute_instance.webservers[*].network_interface[0].access_config[0].nat_ip
}

output "lb-ip" {
  value = google_compute_global_address.default.address
}
