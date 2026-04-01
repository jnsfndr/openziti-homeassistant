# OpenZiti Tunnel — Home Assistant Add-on

Zero Trust bidirectional networking for Home Assistant via [OpenZiti](https://openziti.io/).

This add-on runs `ziti-edge-tunnel` in `run` mode, providing:
- **Inbound**: Access Home Assistant from your Ziti network
- **Outbound**: Access Ziti services (e.g., AI servers, databases) from Home Assistant

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the "OpenZiti Tunnel" add-on
3. Configure the add-on (see below)
4. Start the add-on

## Configuration

### EnrollmentJWT

Paste the JWT token from your OpenZiti controller here. After the add-on starts, it will enroll the identity automatically. You can clear this field after successful enrollment — the identity is persisted in the identity directory.

### IdentityDirectory

Where enrolled identity files are stored. Default: `/share/openziti/identities`

This directory is in the Home Assistant `/share` mount, so it survives add-on reinstallation.

### LogLevel

Verbosity level for `ziti-edge-tunnel`. Range: 1 (minimal) to 7 (maximum debug). Default: 3.

### UpstreamResolver

DNS server for non-Ziti queries. Leave empty to auto-detect from Home Assistant's DNS configuration. Fallback: `1.1.1.1`.

### ResolutionRange

CIDR range used for Ziti service IP assignments and the TUN interface. Default: `100.64.0.1/10` (Ziti-Standard, DNS-Nameserver auf `100.64.0.2`).

## How It Works

The add-on creates a TUN network interface on the Home Assistant host and runs a DNS resolver for Ziti service names. Because it runs with `host_network: true` and `NET_ADMIN` privileges, the tunnel integrates directly into the host's network stack.

When Home Assistant (or any integration) resolves a Ziti service name, the tunnel's DNS resolver returns an IP from the resolution range. Traffic to that IP is routed through the TUN interface into the Ziti overlay network.

## Enrollment Workflow

1. Create an endpoint identity in your OpenZiti controller
2. Download the JWT enrollment token
3. Paste the JWT into the add-on's `EnrollmentJWT` configuration field
4. Start (or restart) the add-on
5. The JWT is saved as a `.jwt` file in the identity directory
6. `ziti-edge-tunnel` automatically enrolls the JWT at startup and creates a `.json` identity
7. Check the add-on logs to verify enrollment succeeded
8. Clear the `EnrollmentJWT` field (recommended — the identity is already persisted)

Multiple identities are supported — repeat the enrollment process with different JWTs.

**Alternative**: You can also manually place `.jwt` files in the identity directory (`/share/openziti/identities/`). They will be auto-enrolled at the next add-on start.

## DNS Behavior

The add-on configures two DNS servers in Home Assistant:

1. **Ziti DNS** (`100.64.0.2`) — resolves Ziti service names to overlay IPs
2. **Original DNS** (DHCP-assigned) — resolves all other domains

When the Ziti nameserver receives a query for an unknown domain, it responds with `REFUSE`. Home Assistant then automatically falls back to the second (original) DNS server. This ensures normal internet resolution is unaffected.

When the add-on stops, the original DNS configuration is restored.

## Troubleshooting

- **No identities found**: Enroll at least one identity via the JWT configuration
- **Enrollment failed**: Check that the JWT is valid and not expired; check add-on logs for details
- **DNS not resolving Ziti services**: Verify the add-on is running and check that HA DNS shows the Ziti resolver as first server
- **Cannot reach Ziti services from HA**: Ensure the service is configured for `dial` access in your Ziti policies
- **Permission errors on IPC socket**: The add-on automatically cleans up `/tmp/.ziti` on start; if issues persist, restart the add-on

## Architecture Support

| Architecture | Supported |
|-------------|-----------|
| amd64       | Yes       |
| aarch64     | Yes       |
| armv7       | Yes       |
| armhf       | No        |
| i386        | No        |

## Credits

Based on the original [HA-NetFoundry](https://github.com/NicFragale/HA-NetFoundry) add-on by Nic Fragale.
Modernized with pre-built binaries and updated for current Home Assistant add-on standards.
