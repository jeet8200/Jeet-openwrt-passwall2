OpenWrt Passwall2/Xray Configuration Tool
========================================

[Features]
- One-click Passwall2 + Xray installation
- Geo rules with optional countries
- Firewall hardening & DNS-over-HTTPS
- Performance tuning (experimental)
- Built-in verification system

# OpenWrt Passwall2/Xray Configuration Script

![OpenWrt](https://img.shields.io/badge/OpenWrt-Supported-brightgreen) 
![Shell](https://img.shields.io/badge/Shell-Bash-blue)

## 📥 Installation
```bash
wget https://raw.githubusercontent.com/your-repo/main/passwall_setup.sh -O /root/passwall_setup.sh
chmod +x /root/passwall_setup.sh
./passwall_setup.sh
```

[Main Menu Options]   Make sure Get Backup Befor Using
1) Install Dependencies
2) Update Geo Files
3) Configure Passwall2  
4) Harden Firewall
5) Setup DNS over HTTPS
6) Verify Installation
7) Experimental Optimizations ⚠️
8) Run Complete Setup
0) Exit

[Geo File Management]
Available options:
1) Iran (ir) [Default]
2) China (cn)
3) Russia (ru)
4) Custom countries

Example custom input: "ir cn de"

[Verification Commands]
Check Xray version:
xray -version

Check Passwall status:
/etc/init.d/passwall2 status

Check geo files:
ls -lh /usr/share/xray/geo*.dat

[Rollback Procedures]
Restore firewall:
cp /etc/config/firewall.bak /etc/config/firewall
/etc/init.d/firewall restart

Restore network settings:
cp /etc/sysctl.conf.bak /etc/sysctl.conf
sysctl -p

[Troubleshooting]
View logs:
logread | grep passwall
tail -n 50 /tmp/xray.log

Reinstall components:
opkg install --force-reinstall xray-core luci-app-passwall2

[License]
MIT License
