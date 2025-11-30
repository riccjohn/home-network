# Scripts

Service-specific scripts organized by service.

## Pi-hole Scripts

Located in `scripts/pihole/`:

- **`test-pihole.sh`** - Quick tests to verify Pi-hole is working correctly
  - Checks container status
  - Tests DNS resolution
  - Tests ad-blocking
  - Checks web interface accessibility
  - Shows recent activity

- **`diagnose-pihole.sh`** - Network diagnostic tool
  - Comprehensive network connectivity checks
  - Firewall status
  - Port listening status
  - DNS resolution tests
  - Helps identify why devices aren't using Pi-hole DNS

- **`update-server-ip.sh`** - Update server IP in .env file
  - Auto-detects current server IP
  - Updates or adds SERVER_IP to .env
  - Useful if server IP changes

## Usage

All scripts should be run from the project root:

```bash
./scripts/pihole/test-pihole.sh
./scripts/pihole/diagnose-pihole.sh
./scripts/pihole/update-server-ip.sh
```

