# terraform-google-cloud-sql

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
Cloud SQL instance (`google_sql_database_instance`). It provisions a managed
PostgreSQL, MySQL or SQL Server instance with configurable tier, disk,
availability, networking and backups.

## Defaults

The module ships with defaults that are safe to apply to production and that
have to be opted out of deliberately:

- daily automated backups with point-in-time recovery and 7 retained backups;
- deletion protection on both sides — Terraform's plan-time guard *and* the
  Cloud SQL API flag, so a delete issued outside Terraform is refused too;
- `ssl_mode = "ENCRYPTED_ONLY"`, so unencrypted client connections are rejected;
- no authorized networks, so the public endpoint accepts no direct connections;
- `0.0.0.0/0` (and `::/0`) rejected outright as an authorized network.

The instance still gets a public IPv4 address by default, because a private-IP
instance needs a VPC with private services access already in place. For
production, set `ipv4_enabled = false` and pass `private_network` — see
[`examples/private-ip`](examples/private-ip).

The module deliberately does not manage databases, users or the root password;
create those with `google_sql_user` / `google_sql_database` so no credential
material passes through this module's state.

## Usage

```hcl
module "cloud_sql" {
  source = "github.com/moveeeax/terraform-google-cloud-sql"

  project_id        = var.project_id
  name              = "prod-db"
  region            = "us-central1"
  database_version  = "POSTGRES_15"
  tier              = "db-custom-2-7680"
  availability_type = "REGIONAL"

  ipv4_enabled    = false
  private_network = google_compute_network.this.id
}
```

Runnable examples live in [`examples/basic`](examples/basic) (public IP, no
network prerequisites) and [`examples/private-ip`](examples/private-ip)
(private IP with the VPC peering it requires).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.10  |

`terraform test` (`tests/`) additionally requires Terraform or OpenTofu >= 1.7
for `mock_provider`; the module itself does not.

## Inputs

| Name                             | Description                                                                        | Type                                       | Default             | Required |
|----------------------------------|------------------------------------------------------------------------------------|--------------------------------------------|---------------------|:--------:|
| `project_id`                     | ID of the project in which to create the instance.                                 | `string`                                   | n/a                 |   yes    |
| `name`                           | Name of the Cloud SQL instance.                                                    | `string`                                   | n/a                 |   yes    |
| `region`                         | Region in which to create the instance.                                            | `string`                                   | n/a                 |   yes    |
| `database_version`               | Database engine version.                                                           | `string`                                   | `"POSTGRES_15"`     |    no    |
| `tier`                           | Machine tier for the instance.                                                     | `string`                                   | `"db-f1-micro"`     |    no    |
| `availability_type`              | Availability type: ZONAL or REGIONAL.                                              | `string`                                   | `"ZONAL"`           |    no    |
| `disk_size`                      | Data disk size in GB.                                                              | `number`                                   | `10`                |    no    |
| `deletion_protection`            | Terraform plan-time guard against destroying the instance.                         | `bool`                                     | `true`              |    no    |
| `deletion_protection_enabled`    | Cloud SQL API guard against deleting the instance, in or out of Terraform.         | `bool`                                     | `true`              |    no    |
| `user_labels`                    | User labels applied to the instance.                                               | `map(string)`                              | `{}`                |    no    |
| `ipv4_enabled`                   | Whether the instance gets a public IPv4 address.                                   | `bool`                                     | `true`              |    no    |
| `private_network`                | VPC self link for the private IP. Required when `ipv4_enabled` is false.           | `string`                                   | `null`              |    no    |
| `authorized_networks`            | CIDR ranges allowed to reach the public IP. `0.0.0.0/0` is rejected.               | `list(object({ name, value }))`            | `[]`                |    no    |
| `ssl_mode`                       | TLS enforcement for incoming connections.                                          | `string`                                   | `"ENCRYPTED_ONLY"`  |    no    |
| `backup_enabled`                 | Whether automated backups are taken.                                               | `bool`                                     | `true`              |    no    |
| `backup_start_time`              | Start of the daily backup window in UTC, `HH:MM`.                                  | `string`                                   | `"03:00"`           |    no    |
| `backup_location`                | Region or multi-region where backups are stored.                                   | `string`                                   | `null`              |    no    |
| `point_in_time_recovery_enabled` | Whether point-in-time recovery is enabled. Requires `backup_enabled`.              | `bool`                                     | `true`              |    no    |
| `retained_backups`               | Number of automated backups to keep (1–365).                                       | `number`                                   | `7`                 |    no    |

## Outputs

| Name                | Description                                       |
|---------------------|---------------------------------------------------|
| `id`                | Identifier of the Cloud SQL instance.            |
| `name`              | Name of the Cloud SQL instance.                  |
| `connection_name`   | Connection name used by the Auth proxy.          |
| `public_ip_address` | Public IPv4 address of the instance, if enabled. |
| `private_ip_address` | Private IP address, if a `private_network` is attached. |

## Destroying an instance

Both deletion guards are on by default, so a destroy takes two steps:

```hcl
deletion_protection         = false
deletion_protection_enabled = false
```

Apply that first, then `terraform destroy`. This is deliberate — it is what
stops a stray destroy from taking the database with it.

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test          # mocked provider, no credentials or network needed
```

## License

[MIT](LICENSE)
