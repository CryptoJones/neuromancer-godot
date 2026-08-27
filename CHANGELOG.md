# Changelog

All notable changes to **The Flatline Sessions** are documented here.

## [1.0.6] — 2026-08-27

### Changed
- macOS archives are now signed as **Developer ID Application: Aaron Clark
  (J6P99Q4479)**. Previous releases were signed as Patrick Hannah (GPKDR6QL9Q);
  that private key was destroyed and cannot be reissued, so the signing identity
  moved to one we still hold. Builds remain signed but **not notarized**.
- Release notes no longer attribute the signature to the retired identity.

## [1.0.5] — 2026-07-21

### Added
- Reproducible GitHub Actions tests and three-platform release exports.
- macOS release archives are signed with a verified Developer ID Application
  identity in a temporary native-runner keychain. The app remains unnotarized.
- SHA-256 manifests accompany every release archive.
