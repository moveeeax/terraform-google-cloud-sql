terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.10"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# A private-IP Cloud SQL instance needs a VPC with a private services access
# connection, which is what the three resources below set up.
resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = "example-cloud-sql"
  auto_create_subnetworks = false
}

resource "google_compute_global_address" "private_service_range" {
  project       = var.project_id
  name          = "example-cloud-sql-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "this" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}

module "cloud_sql" {
  source = "../.."

  project_id       = var.project_id
  name             = "example-private-postgres"
  region           = var.region
  database_version = "POSTGRES_15"
  tier             = "db-custom-2-7680"

  # No public IP: the instance is only reachable from inside the VPC.
  ipv4_enabled    = false
  private_network = google_compute_network.this.id

  availability_type = "REGIONAL"
  backup_location   = var.region

  depends_on = [google_service_networking_connection.this]
}

variable "project_id" {
  description = "Project ID to deploy the example instance into."
  type        = string
}

variable "region" {
  description = "Region for the google provider, instance and backups."
  type        = string
  default     = "us-central1"
}

output "connection_name" {
  value = module.cloud_sql.connection_name
}

output "private_ip_address" {
  value = module.cloud_sql.private_ip_address
}
