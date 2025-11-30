# Pi-hole Troubleshooting Guide

## Issue: Pi-hole works locally but not from other devices

This is a common issue that usually relates to router DHCP configuration, not just DNS settings.

### Common Causes

1. **Router DNS vs DHCP DNS Settings** - These are often separate!
   - Router DNS: What the router itself uses
   - DHCP DNS: What the router tells devices to use
   - You need to configure **both** or at least the DHCP DNS

2. **Devices with cached DNS settings**
3. **Firewall blocking port 53**
4. **Router not distributing DNS via DHCP**

---

## Step-by-Step Troubleshooting

### Step 1: Verify Pi-hole is accessible from network

**On a client device (not the server), test DNS:**

```bash
# Test if you can reach Pi-hole DNS
dig @YOUR_SERVER_IP google.com

# Or using nslookup
nslookup google.com YOUR_SERVER_IP
```

**If this fails:**
- Check firewall on server: `sudo ufw status`
- Allow DNS: `sudo ufw allow 53/tcp` and `sudo ufw allow 53/udp`
- Check if Pi-hole container is listening: `docker compose logs pihole`

### Step 2: Check what DNS your devices are actually using

**On a client device, check DNS settings:**

**Linux:**
```bash
cat /etc/resolv.conf
# Should show your server IP
```

**Mac:**
```bash
scutil --dns | grep nameserver
# Should show your server IP
```

**Windows:**
```cmd
ipconfig /all
# Look for "DNS Servers" - should show your server IP
```

**Android:**
- Settings → Wi-Fi → Long press network → Modify → Advanced → IP settings
- Check DNS 1 and DNS 2

**iPhone/iPad:**
- Settings → Wi-Fi → Tap (i) next to network → Configure DNS
- Should show your server IP

**If devices show different DNS servers (like 8.8.8.8 or router IP):**
- Your router is not distributing Pi-hole DNS via DHCP
- Continue to Step 3

### Step 3: Configure Router DHCP DNS Settings

**This is the most common issue!** Many routers have separate settings:

1. **Router DNS Settings** (what router uses) - You may have already set this
2. **DHCP DNS Settings** (what router tells devices) - This is what you need!

**Look for these settings in your router:**
- "DHCP Server Settings"
- "DHCP DNS" or "DHCP DNS Server"
- "LAN DNS Settings"
- "DHCP Options" or "DHCP Option 6"

**Set DHCP DNS to:**
- Primary DNS: `YOUR_SERVER_IP`
- Secondary DNS: `8.8.8.8` or `1.1.1.1`

**Router-specific instructions:**

**TP-Link:**
- Advanced → Network → DHCP Server
- Set "Primary DNS" and "Secondary DNS"
- Save and restart router

**Netgear:**
- Advanced → Setup → LAN Setup
- Under "DHCP Server Settings", set DNS servers
- Apply

**ASUS:**
- LAN → DHCP Server
- Set "DNS Server 1" and "DNS Server 2"
- Apply

**Ubiquiti/UniFi:**
- Settings → Networks → [Your Network] → DHCP
- Set "DHCP Name Server" to "Manual"
- Enter your server IP

**Generic/Other routers:**
- Look for "DHCP" or "LAN" settings
- Find "DNS Server" or "DHCP DNS" option
- Set to your server IP

### Step 4: Force devices to get new DNS settings

After changing router DHCP settings:

1. **Restart your router** (power cycle)
2. **On each device:**
   - **Forget and reconnect to Wi-Fi** (mobile devices)
   - **Release and renew DHCP lease:**
     ```bash
     # Linux
     sudo dhclient -r && sudo dhclient
     
     # Mac
     sudo ipconfig set en0 DHCP
     
     # Windows
     ipconfig /release
     ipconfig /renew
     ```
   - **Or restart the device**

### Step 5: Verify in Pi-hole Dashboard

1. Go to Pi-hole admin: `http://YOUR_SERVER_IP/admin`
2. Check **Query Log** - you should see queries from different client IPs
3. Check **Dashboard** → **Top Clients** - should show your devices
4. Check **Dashboard** → **Top Blocked** - should show blocked domains

**If Query Log is empty or only shows server IP:**
- Devices are still not using Pi-hole
- Go back to Step 3 and verify DHCP DNS settings

### Step 6: Manual DNS Test (Temporary Workaround)

To test if Pi-hole works, manually set DNS on a device:

**Android:**
- Settings → Wi-Fi → Long press network → Modify
- Advanced → IP settings → Static
- Set DNS 1: `YOUR_SERVER_IP`
- Save

**iPhone/iPad:**
- Settings → Wi-Fi → Tap (i) → Configure DNS → Manual
- Add your server IP
- Save

**Mac:**
- System Settings → Network → Wi-Fi → Details → DNS
- Add your server IP
- Apply

**If manual DNS works but DHCP doesn't:**
- Confirms it's a router DHCP configuration issue
- Continue troubleshooting router settings

---

## Alternative: Use Pi-hole as DHCP Server

If your router doesn't support setting DHCP DNS, you can use Pi-hole as the DHCP server:

**⚠️ Warning:** This disables your router's DHCP. Make sure you understand the implications!

1. **In Pi-hole admin:**
   - Settings → DHCP
   - Enable DHCP server
   - Set IP range (e.g., 192.168.1.100-192.168.1.200)
   - Set router IP (your router's IP)
   - Set domain name
   - Save

2. **Disable DHCP on your router:**
   - Find DHCP settings in router
   - Disable DHCP server
   - Save

3. **Restart Pi-hole:**
   ```bash
   docker compose restart pihole
   ```

4. **Restart devices** to get new DHCP leases

---

## Firewall Configuration

If devices can't reach Pi-hole, check firewall:

```bash
# Check firewall status
sudo ufw status

# Allow DNS (if not already allowed)
sudo ufw allow 53/tcp
sudo ufw allow 53/udp

# Check if Pi-hole is listening
sudo netstat -tulpn | grep :53
# Or
sudo ss -tulpn | grep :53
```

---

## Testing Checklist

- [ ] Pi-hole container is running: `docker compose ps`
- [ ] Pi-hole is listening on port 53: `sudo netstat -tulpn | grep :53`
- [ ] Firewall allows port 53: `sudo ufw status`
- [ ] Can resolve DNS from server: `dig @127.0.0.1 google.com`
- [ ] Can resolve DNS from client: `dig @YOUR_SERVER_IP google.com`
- [ ] Router DHCP DNS is set to server IP
- [ ] Devices show server IP as DNS: `cat /etc/resolv.conf` (Linux)
- [ ] Pi-hole Query Log shows queries from multiple devices
- [ ] Pi-hole Dashboard shows multiple clients

---

## Still Not Working?

1. **Check Pi-hole logs:**
   ```bash
   docker compose logs pihole
   ```

2. **Verify network configuration:**
   ```bash
   docker compose exec pihole cat /etc/pihole/setupVars.conf
   ```

3. **Test from server:**
   ```bash
   # Should work
   dig @127.0.0.1 google.com
   
   # Test from another device on network
   dig @YOUR_SERVER_IP google.com
   ```

4. **Check router logs** (if available) for DHCP activity

5. **Try manual DNS on one device** to confirm Pi-hole works

6. **Consider using Pi-hole as DHCP server** (see above)

---

## Quick Diagnostic Script

Run the diagnostic script on your server:

```bash
./scripts/pihole/diagnose-pihole.sh
```

This will check:
- Container status
- Port 53 listening status
- Firewall configuration
- DNS resolution
- Recent Pi-hole activity

