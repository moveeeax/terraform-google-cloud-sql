locals {
  # MySQL turns on point-in-time recovery through binary logging, while
  # PostgreSQL and SQL Server use point_in_time_recovery_enabled. Sending the
  # field that does not belong to the engine is rejected by the Cloud SQL API,
  # so exactly one of the two is set and the other is left null.
  is_mysql = startswith(upper(var.database_version), "MYSQL")
}

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    user_labels       = var.user_labels

    # Server-side guard. Unlike the resource-level deletion_protection, which
    # only stops Terraform, this one makes the Cloud SQL API itself refuse to
    # delete the instance until the flag is turned off and applied.
    deletion_protection_enabled = var.deletion_protection_enabled

    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      private_network = var.private_network
      ssl_mode        = var.ssl_mode

      dynamic "authorized_networks" {
        for_each = var.authorized_networks

        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      location                       = var.backup_location
      point_in_time_recovery_enabled = local.is_mysql ? null : var.point_in_time_recovery_enabled
      binary_log_enabled             = local.is_mysql ? var.point_in_time_recovery_enabled : null

      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.ipv4_enabled || var.private_network != null
      error_message = "private_network must be set when ipv4_enabled is false, otherwise the instance has no way to accept connections."
    }

    precondition {
      condition     = var.backup_enabled || !var.point_in_time_recovery_enabled
      error_message = "point_in_time_recovery_enabled requires backup_enabled to be true. Set point_in_time_recovery_enabled = false as well if you really intend to run this instance with no recovery point."
    }
  }
}
