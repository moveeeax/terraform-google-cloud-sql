# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `database_flags`: set Cloud SQL database flags as a map of name to value.
  Defaults to `{}`, so existing instances plan unchanged.
- `cis_flags`: opt-in baseline of the CIS Google Cloud Platform Foundation
  Benchmark v5.0.0 database flags for the engine in `database_version`
  (PostgreSQL, MySQL or SQL Server). Defaults to `false` because several of the
  flags restart the instance when first applied. Explicit `database_flags`
  override baseline values of the same name.

## [1.1.0] - 2026-11-05

### Changed

- Bound the google provider to `>= 5.10, < 9.0` and validate the 5.10.0 floor
  in CI (#7).
- CI: group Dependabot updates monthly and auto-merge patches (#6).

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-google-cloud-sql/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-google-cloud-sql/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-google-cloud-sql/releases/tag/v1.0.0
