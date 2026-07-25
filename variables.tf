variable "project_id" {
  description = "ID of the project in which to create the instance."
  type        = string
}

variable "name" {
  description = "Name of the Cloud SQL instance."
  type        = string
}

variable "region" {
  description = "Region in which to create the instance."
  type        = string
}

variable "database_version" {
  description = "Database engine version, e.g. POSTGRES_15 or MYSQL_8_0."
  type        = string
  default     = "POSTGRES_15"

  validation {
    condition = anytrue([
      for engine in ["POSTGRES_", "MYSQL_", "SQLSERVER_"] :
      startswith(upper(var.database_version), engine)
    ])
    error_message = "database_version must start with POSTGRES_, MYSQL_ or SQLSERVER_ (e.g. POSTGRES_15, MYSQL_8_0)."
  }
}

variable "tier" {
  description = "Machine tier for the instance, e.g. db-f1-micro or db-custom-2-7680."
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "Availability type: ZONAL or REGIONAL (regional enables high availability)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be either ZONAL or REGIONAL."
  }
}

variable "disk_size" {
  description = "Data disk size in GB."
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size >= 10
    error_message = "disk_size must be at least 10 GB."
  }
}

variable "deletion_protection" {
  description = "Whether Terraform itself refuses to destroy the instance. This is a plan-time guard only; it does not stop a delete issued outside Terraform."
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "Whether the Cloud SQL API refuses to delete the instance. Must be turned off and applied before the instance can be destroyed, by Terraform or otherwise."
  type        = bool
  default     = true
}

variable "user_labels" {
  description = "User labels applied to the instance."
  type        = map(string)
  default     = {}
}

variable "ipv4_enabled" {
  description = "Whether the instance gets a public IPv4 address. Prefer false together with private_network so the database is only reachable from inside the VPC."
  type        = bool
  default     = true
}

variable "private_network" {
  description = "Self link of the VPC network to attach a private IP to, e.g. projects/p/global/networks/n. Required when ipv4_enabled is false. The network must already have a private services access connection."
  type        = string
  default     = null
}

variable "authorized_networks" {
  description = "CIDR ranges allowed to reach the public IP. Empty by default, which means the public endpoint accepts no direct connections."
  type = list(object({
    name  = string
    value = string
  }))
  default = []

  validation {
    condition = alltrue([
      for network in var.authorized_networks :
      !contains(["0.0.0.0/0", "0.0.0.0", "::/0"], trimspace(network.value))
    ])
    error_message = "authorized_networks must not open the instance to the whole internet. Remove the 0.0.0.0/0 (or ::/0) entry and list the specific ranges that need access, or connect over private IP or the Cloud SQL Auth proxy."
  }

  validation {
    condition     = length(var.authorized_networks) == length(distinct([for network in var.authorized_networks : network.name]))
    error_message = "authorized_networks entries must have unique names."
  }
}

variable "ssl_mode" {
  description = "TLS enforcement for incoming connections: ENCRYPTED_ONLY, TRUSTED_CLIENT_CERTIFICATE_REQUIRED or ALLOW_UNENCRYPTED_AND_ENCRYPTED."
  type        = string
  default     = "ENCRYPTED_ONLY"

  validation {
    condition = contains([
      "ALLOW_UNENCRYPTED_AND_ENCRYPTED",
      "ENCRYPTED_ONLY",
      "TRUSTED_CLIENT_CERTIFICATE_REQUIRED",
    ], var.ssl_mode)
    error_message = "ssl_mode must be one of ALLOW_UNENCRYPTED_AND_ENCRYPTED, ENCRYPTED_ONLY or TRUSTED_CLIENT_CERTIFICATE_REQUIRED."
  }
}

variable "backup_enabled" {
  description = "Whether automated backups are taken. Turning this off leaves the instance with no recoverable copy."
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "Start of the daily backup window in UTC, HH:MM."
  type        = string
  default     = "03:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_start_time))
    error_message = "backup_start_time must be a 24-hour HH:MM time, e.g. 03:00."
  }
}

variable "backup_location" {
  description = "Region or multi-region where backups are stored. Null keeps them in the instance's own multi-region."
  type        = string
  default     = null
}

variable "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled (write-ahead logs on PostgreSQL and SQL Server, binary logs on MySQL). Requires backup_enabled."
  type        = bool
  default     = true
}

variable "retained_backups" {
  description = "Number of automated backups to keep."
  type        = number
  default     = 7

  validation {
    condition     = var.retained_backups >= 1 && var.retained_backups <= 365 && floor(var.retained_backups) == var.retained_backups
    error_message = "retained_backups must be a whole number between 1 and 365."
  }
}
