
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

resource "google_compute_instance" "vm_instance" {
  name         = "cis91"
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

  attached_disk {
    source = google_compute_disk.dokuwiki.self_link
    device_name = "systemDisk"
  }

  attached_disk {
    source = google_compute_disk.dokuwiki1.self_link
    device_name = "dataDisk"
  }
}

resource "google_compute_disk" "dokuwiki" {
  name  = "dokuwiki"
  type  = "pd-ssd"
  zone  = "us-central1-c"
  labels = {
    environment = "dev"
  }
  size = "16"
}

resource "google_compute_disk" "dokuwiki1" {
  name  = "dokuwiki1"
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
    ports = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
