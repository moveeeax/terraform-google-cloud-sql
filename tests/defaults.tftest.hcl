# Runs with a mocked provider, so no credentials and no network access are
# needed: `terraform test` (or `tofu test`).
#
# mock_provider requires Terraform >= 1.7 / OpenTofu >= 1.7. That is a
# requirement of the test tooling only -- the module itself still supports the
# >= 1.5 declared in versions.tf, so do not raise required_version for this.

mock_provider "google" {}

variables {
  project_id = "test-project"
  name       = "test-instance"
  region     = "us-central1"
}

run "defaults_are_safe" {
  command = plan

  assert {
    condition     = google_sql_database_instance.this.deletion_protection == true
    error_message = "Terraform-side deletion protection must default to on."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].deletion_protection_enabled == true
    error_message = "API-side deletion protection must default to on, otherwise a delete outside Terraform destroys the instance."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].enabled == true
    error_message = "Automated backups must default to on, otherwise the instance has no recoverable copy."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].point_in_time_recovery_enabled == true
    error_message = "Point-in-time recovery must default to on for PostgreSQL."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].backup_retention_settings[0].retained_backups == 7
    error_message = "Seven automated backups should be retained by default."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ssl_mode == "ENCRYPTED_ONLY"
    error_message = "Unencrypted client connections must not be accepted by default."
  }

  assert {
    condition     = length(google_sql_database_instance.this.settings[0].ip_configuration[0].authorized_networks) == 0
    error_message = "No network should be authorized to reach the public endpoint by default."
  }

  assert {
    condition     = length(google_sql_database_instance.this.settings[0].database_flags) == 0
    error_message = "No database flags should be set by default, so upgrading the module does not change or restart existing instances."
  }
}

run "mysql_uses_binary_logging_for_pitr" {
  command = plan

  variables {
    database_version = "MYSQL_8_0"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].binary_log_enabled == true
    error_message = "MySQL point-in-time recovery is driven by binary logging and must be enabled."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].point_in_time_recovery_enabled == null
    error_message = "point_in_time_recovery_enabled is not valid for MySQL and must be left unset."
  }
}

run "authorized_networks_are_passed_through" {
  command = plan

  variables {
    authorized_networks = [
      { name = "office", value = "203.0.113.0/24" },
    ]
  }

  assert {
    condition     = one(google_sql_database_instance.this.settings[0].ip_configuration[0].authorized_networks).value == "203.0.113.0/24"
    error_message = "A specific authorized network should be configured as given."
  }
}

run "rejects_world_open_authorized_network" {
  command = plan

  variables {
    authorized_networks = [
      { name = "everyone", value = "0.0.0.0/0" },
    ]
  }

  expect_failures = [var.authorized_networks]
}

run "rejects_world_open_ipv6_authorized_network" {
  command = plan

  variables {
    authorized_networks = [
      { name = "everyone", value = "::/0" },
    ]
  }

  expect_failures = [var.authorized_networks]
}

run "rejects_duplicate_authorized_network_names" {
  command = plan

  variables {
    authorized_networks = [
      { name = "office", value = "203.0.113.0/24" },
      { name = "office", value = "198.51.100.0/24" },
    ]
  }

  expect_failures = [var.authorized_networks]
}

run "rejects_invalid_ssl_mode" {
  command = plan

  variables {
    ssl_mode = "OPTIONAL"
  }

  expect_failures = [var.ssl_mode]
}

run "rejects_invalid_availability_type" {
  command = plan

  variables {
    availability_type = "MULTI_REGION"
  }

  expect_failures = [var.availability_type]
}

run "rejects_unknown_database_engine" {
  command = plan

  variables {
    database_version = "ORACLE_19"
  }

  expect_failures = [var.database_version]
}

run "rejects_malformed_backup_start_time" {
  command = plan

  variables {
    backup_start_time = "3am"
  }

  expect_failures = [var.backup_start_time]
}

run "rejects_out_of_range_retained_backups" {
  command = plan

  variables {
    retained_backups = 0
  }

  expect_failures = [var.retained_backups]
}

run "rejects_private_ip_without_network" {
  command = plan

  variables {
    ipv4_enabled = false
  }

  expect_failures = [google_sql_database_instance.this]
}

run "rejects_point_in_time_recovery_without_backups" {
  command = plan

  variables {
    backup_enabled = false
  }

  expect_failures = [google_sql_database_instance.this]
}

run "private_ip_only_instance_plans" {
  command = plan

  variables {
    ipv4_enabled    = false
    private_network = "projects/test-project/global/networks/test-network"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "The instance should have no public IP when ipv4_enabled is false."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].private_network == "projects/test-project/global/networks/test-network"
    error_message = "The private network should be attached as given."
  }
}

run "backups_can_be_disabled_deliberately" {
  command = plan

  variables {
    backup_enabled                 = false
    point_in_time_recovery_enabled = false
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].enabled == false
    error_message = "Disabling backups explicitly, together with PITR, should still plan."
  }
}

run "database_flags_are_passed_through" {
  command = plan

  variables {
    database_flags = {
      log_connections = "on"
      work_mem        = "8192"
    }
  }

  assert {
    condition     = length(google_sql_database_instance.this.settings[0].database_flags) == 2
    error_message = "Only the flags given in database_flags should be set when cis_flags is off."
  }

  assert {
    condition     = { for flag in google_sql_database_instance.this.settings[0].database_flags : flag.name => flag.value }["work_mem"] == "8192"
    error_message = "A database flag should be set to the value given."
  }
}

run "cis_flags_postgres_baseline" {
  command = plan

  variables {
    cis_flags = true
  }

  assert {
    condition = {
      for flag in google_sql_database_instance.this.settings[0].database_flags : flag.name => flag.value
      } == {
      "log_connections"            = "on"
      "log_disconnections"         = "on"
      "log_min_messages"           = "warning"
      "log_min_error_statement"    = "error"
      "log_min_duration_statement" = "-1"
      "cloudsql.enable_pgaudit"    = "on"
    }
    error_message = "cis_flags on PostgreSQL should set exactly the PostgreSQL CIS baseline."
  }
}

run "cis_flags_mysql_baseline" {
  command = plan

  variables {
    database_version = "MYSQL_8_0"
    cis_flags        = true
  }

  assert {
    condition = {
      for flag in google_sql_database_instance.this.settings[0].database_flags : flag.name => flag.value
      } == {
      "skip_show_database" = "on"
      "local_infile"       = "off"
    }
    error_message = "cis_flags on MySQL should set exactly the MySQL CIS baseline."
  }
}

run "cis_flags_sqlserver_baseline" {
  command = plan

  variables {
    database_version = "SQLSERVER_2019_STANDARD"
    cis_flags        = true
  }

  assert {
    condition = {
      for flag in google_sql_database_instance.this.settings[0].database_flags : flag.name => flag.value
      } == {
      "external scripts enabled"          = "off"
      "cross db ownership chaining"       = "off"
      "remote access"                     = "off"
      "3625"                              = "on"
      "contained database authentication" = "off"
    }
    error_message = "cis_flags on SQL Server should set exactly the SQL Server CIS baseline."
  }
}

run "database_flags_override_cis_baseline" {
  command = plan

  variables {
    cis_flags = true
    database_flags = {
      log_min_duration_statement = "1000"
    }
  }

  assert {
    condition     = length(google_sql_database_instance.this.settings[0].database_flags) == 6
    error_message = "Overriding a baseline flag should replace it, not add a duplicate."
  }

  assert {
    condition     = { for flag in google_sql_database_instance.this.settings[0].database_flags : flag.name => flag.value }["log_min_duration_statement"] == "1000"
    error_message = "An explicit database_flags value should win over the CIS baseline."
  }
}

run "rejects_empty_database_flag_value" {
  command = plan

  variables {
    database_flags = {
      log_connections = ""
    }
  }

  expect_failures = [var.database_flags]
}
