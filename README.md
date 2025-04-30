# Secure Home Server with Docker Compose and Traefik

A secure, containerized home server setup using Docker Compose and Traefik for reverse proxying and HTTPS termination. This setup provides secure external access to various self-hosted services through HTTPS and subdomains.

## ⚠️ Security Notice

This setup exposes services to the internet. While we implement strong security measures, please understand the risks and consider alternatives like VPNs for even more secure access.

## Prerequisites

- Ubuntu Server (latest LTS recommended)
- SSH access to the server
- Git
- Docker and Docker Compose
- A real domain name (e.g., `yourdomain.com`)
- Control over your domain's DNS settings
- Control over your router's port forwarding settings
- Basic understanding of Linux, Docker, and networking concepts

## Project Structure

```text
my-home-server/
├── .github/
│   └── workflows/
│       └── ci.yml
├── traefik/
│   └── traefik.yml
├── homepage/
│   └── config/
│       ├── settings.yaml
│       └── services.yaml
├── service-configs/
│   ├── homeassistant/
│   ├── syncthing/
│   ├── jellyfin/
│   ├── calibre/
│   └── pihole/
├── scripts/
│   ├── deploy.sh
│   ├── teardown.sh
│   └── update.sh
├── docker-compose.yml
├── env.example
└── README.md
```

## Setup Instructions

### 1. Initial Server Setup

1. **SSH Hardening**
   ```bash
   # On your local machine
   ssh-keygen -t ed25519
   ssh-copy-id your_username@your_server_ip
   ```

2. **Firewall Configuration**
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

### 2. Project Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/my-home-server.git
   cd my-home-server
   ```

2. **Configure Environment**
   ```bash
   cp env.example .env
   nvim .env  # Edit with your values
   ```

3. **DNS Configuration**
   - Create A/AAAA records for each subdomain:
     - `homepage.yourdomain.com`
     - `homeassistant.yourdomain.com`
     - `syncthing.yourdomain.com`
     - `jellyfin.yourdomain.com`
     - `calibre.yourdomain.com`
     - `pihole.yourdomain.com`
   - Point all records to your public IP address

4. **Port Forwarding**
   - Forward TCP ports 80 and 443 to your server's internal IP
   - Consider restricting source IPs if possible

### 3. Service Configuration

1. **Traefik Configuration**
   - Review `traefik/traefik.yml` for security settings
   - Ensure Let's Encrypt email is set in `.env`

2. **Homepage Dashboard**
   - Configure services in `homepage/config/services.yaml`
   - Customize appearance in `homepage/config/settings.yaml`

3. **Service-Specific Configs**
   - Each service has its own directory under `service-configs/`
   - Review and customize as needed

### 4. Deployment

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy services
./scripts/deploy.sh
```

## Security Considerations

### 1. SSH Security
- Use key-based authentication only
- Disable password authentication
- Consider changing the default SSH port
- Use fail2ban for additional protection

### 2. Firewall
- Only allow necessary ports (22, 80, 443)
- Consider restricting source IPs
- Regularly review firewall rules

### 3. Traefik Security
- Dashboard access is restricted to local network
- API is disabled by default
- All services use HTTPS
- Let's Encrypt certificates are automatically managed

### 4. Service Security
- Each service runs in its own container
- Services are isolated from each other
- Regular updates are recommended
- Implement proper authentication for each service

### 5. Pi-hole Considerations
- DNS (port 53) requires special handling
- Web interface is accessible via Traefik
- Consider restricting DNS access to local network

## Maintenance

### Regular Updates
```bash
./scripts/update.sh
```

### Backup Strategy
1. Regular backups of:
   - Service configurations
   - Docker volumes
   - Environment files
2. Test restore procedures periodically

### Monitoring
- Set up monitoring for:
  - Container health
  - Certificate expiration
  - Disk space
  - System resources

## Troubleshooting

### Common Issues

1. **Certificate Issues**
   - Check DNS propagation
   - Verify port forwarding
   - Review Traefik logs

2. **Service Access**
   - Check container status
   - Verify Traefik labels
   - Review service logs

3. **DNS Resolution**
   - Verify Pi-hole configuration
   - Check local DNS settings
   - Test with different DNS servers

## Alternative Access Methods

While this setup uses HTTPS and subdomains for external access, consider these alternatives for enhanced security:

1. **VPN Solutions**
   - WireGuard
   - Tailscale
   - OpenVPN

2. **SSH Tunneling**
   - For temporary access
   - Specific service access

## License

MIT License - See LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

For issues and feature requests, please use the GitHub issue tracker. 