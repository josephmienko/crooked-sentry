# Crooked Sentry (GitOps + Ansible)

GitOps-style home NVR using Ansible for configuration, WireGuard for VPN, Frigate for video, and semantic versioning for releases.

## Quick start
- Fill `compose/.env.sample`, copy to `compose/.env`.
- Encrypt secrets into `ansible/inventory/group_vars/pi/vault.yml` with Ansible Vault.
- Run `make simulate` (dry-run), then `make deploy`.

## Branching & Releases
- Work on `main` (or `develop` if you prefer GitFlow tweaks).
- Tag releases as `vMAJOR.MINOR.PATCH`. A tag triggers CI deploy (see `.github/workflows/deploy.yml`).
