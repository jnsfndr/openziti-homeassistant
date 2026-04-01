# Changelog

## 2.0.0

### Breaking Changes
- Complete rewrite — not backwards-compatible with NicFragale/HA-NetFoundry
- Removed web dashboard (nginx, PHP-FPM, jQuery)
- Dropped `armhf` and `i386` architectures (no pre-built binaries available)
- EnrollmentJWT default changed from "UNSET" to empty string
- LogLevel is now a numeric integer (1-7) instead of a selection list

### New
- Uses pre-built ziti-edge-tunnel binaries from GitHub Releases (v1.11.1)
- Build time reduced from 20+ minutes to under 60 seconds
- Image size drastically reduced (no build tools, no web server)
- Updated to S6-Overlay v3 patterns
- Modern CLI flags (`--identity-dir`, `--dns-ip-range`, `--dns-upstream`, `--verbose`)
- Proper `exec` process management (S6 signals tunnel directly)
- Auto-detection of upstream DNS resolver from Home Assistant

### Removed
- Source compilation via cmake/vcpkg
- nginx + PHP-FPM web dashboard
- jQuery-based status UI
- AWK-based tunnel status parser
- Tempio profile templates

## 1.6.2 (NicFragale/HA-NetFoundry)
- Last version of the original add-on (unmaintained since 2024)
