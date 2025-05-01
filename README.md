# Secure Home Server

A secure, containerized home server setup using Docker Compose, Traefik, and various self-hosted services. This project provides a robust foundation for running personal services with secure external access via HTTPS and subdomains.

## ⚠️ Security First

This setup is designed with security as a top priority. Key security features include:

- HTTPS encryption for all services using Let's Encrypt certificates
- Secure Traefik dashboard access
- Proper network isolation
- Regular security updates
- Firewall configuration recommendations

**IMPORTANT:** Before proceeding, ensure you understand the security implications of exposing services to the internet. Consider using a VPN for additional security.

## 🚀 Features

- **Containerized Services:**

  - Home Assistant (Home automation)
  - Syncthing (File synchronization)
  - Jellyfin (Media server)
  - Calibre (E-book management)
  - Pi-hole (Network-wide ad blocking)
  - Homepage (Dashboard)

- **Infrastructure:**

  - Docker Compose for service orchestration
  - Traefik as reverse proxy with automatic HTTPS
  - Subdomain-based routing
  - Automatic Let's Encrypt certificate management

- **Developer Experience:**
  - VS Code configuration
  - Prettier for code formatting
  - Husky for git hooks
  - asdf for version management
  - pnpm for package management
  - GitHub Actions for CI

## 📋 Prerequisites

- Ubuntu Server (latest LTS recommended)
- SSH access to the server
- Git installed
- Docker and Docker Compose installed
- A real domain name (e.g., `yourdomain.com`)
- Control over DNS settings
- asdf version manager installed
- Port forwarding capability on your router (TCP 80 and 443)

## 🛠️ Developer Setup

1. **Install asdf:**

   ```bash
   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
   echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Install Node.js:**

   ```bash
   asdf plugin add nodejs
   asdf install
   ```

3. **Install pnpm:**

   ```bash
   npm install -g pnpm
   ```

4. **Install Project Dependencies:**

   ```bash
   pnpm install
   ```

5. **VS Code Setup:**
   - Install recommended extensions from `.vscode/extensions.json`
   - Enable format on save
   - Configure Prettier as default formatter

## 🖥️ Server Setup

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/riccjohn/home-network
   cd home-network
   ```

2. **Configure Environment:**

   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

3. **Initial Deployment:**
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh
   ```

## 🌐 DNS Configuration

### External DNS

1. Create A/AAAA records for each subdomain:
   ```
   dashboard.yourdomain.com -> your_public_ip
   homeassistant.yourdomain.com -> your_public_ip
   syncthing.yourdomain.com -> your_public_ip
   jellyfin.yourdomain.com -> your_public_ip
   calibre.yourdomain.com -> your_public_ip
   pihole.yourdomain.com -> your_public_ip
   ```

### Internal DNS

1. Configure Pi-hole to resolve your domain internally
2. Add local DNS entries pointing to your server's internal IP

## 🔒 Port Forwarding

1. Forward these ports to your server's internal IP:
   - TCP 80 (HTTP)
   - TCP 443 (HTTPS)

**WARNING:** Only forward necessary ports. Consider using a VPN for additional security.

## 📦 Service Configuration

Each service has its configuration directory under `service-configs/`:

- `homeassistant/`: Home Assistant configuration
- `syncthing/`: Syncthing configuration
- `jellyfin/`: Jellyfin configuration
- `calibre/`: Calibre configuration
- `pihole/`: Pi-hole configuration

The Homepage dashboard configuration is in `homepage/config/`.

## 🛠️ Scripts

- `deploy.sh`: Initial deployment and service startup
- `teardown.sh`: Stop and remove all services
- `update.sh`: Update all services to latest versions

## 🔒 Security Considerations

### SSH Hardening

1. Disable password authentication
2. Use SSH keys
3. Change default SSH port
4. Enable fail2ban

### Firewall (UFW)

```bash
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### Traefik Dashboard

- Access restricted via middleware
- Basic authentication enabled
- HTTPS enforced

### Regular Updates

- Enable automatic security updates
- Regularly update Docker images
- Monitor for security advisories

### Backups

- Implement regular backups of service data
- Store backups securely
- Test restore procedures

## 🔄 Maintenance

1. **Regular Updates:**

   ```bash
   ./scripts/update.sh
   ```

2. **Monitoring:**
   - Check service logs
   - Monitor disk space
   - Review security logs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [Traefik](https://traefik.io/)
- [Docker](https://www.docker.com/)
- [Let's Encrypt](https://letsencrypt.org/)
- All service maintainers
