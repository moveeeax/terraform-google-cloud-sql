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

module "cloud_sql" {
  source = "../.."

  project_id       = var.project_id
  name             = "example-postgres"
  region           = var.region
  database_version = "POSTGRES_15"
  tier             = "db-f1-micro"

  # Throwaway example instance, so both deletion guards are off to keep it
  # destroyable. Leave them at their default of true for anything real.
  deletion_protection         = false
  deletion_protection_enabled = false
}

variable "project_id" {
  description = "Project ID to deploy the example instance into."
  type        = string
}

variable "region" {
  description = "Region for the google provider and instance."
  type        = string
  default     = "us-central1"
}

output "connection_name" {
  value = module.cloud_sql.connection_name
}
