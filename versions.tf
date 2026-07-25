terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source = "hashicorp/google"
      # 5.10 is the first release carrying ip_configuration.ssl_mode, which the
      # module uses to require TLS.
      version = ">= 5.10"
    }
  }
}
