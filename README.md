OpenWrt Passwall2/Xray Configuration Tool

https://openwrt.org/lib/tpl/openwrt/images/logo.png
*A simple, user-friendly script to configure Passwall2 with Xray on OpenWrt routers*
📌 Features

    🔒 One-click setup for Passwall2 with Xray/V2Ray

    🌍 GeoIP/Geosite management (Iran-focused by default)

    ⚡ Performance optimization (experimental)

    🔄 Rollback functionality for all changes

    🛡️ Firewall hardening and security enhancements

    📊 Verification system to check installation status

🚀 Quick Start

    Copy the script to your OpenWrt router:
    bash

wget https://raw.githubusercontent.com/your-repo/main/passwall_setup.sh -O /root/passwall_setup.sh

Make it executable:
bash

chmod +x /root/passwall_setup.sh

Run the script:
bash

    /root/passwall_setup.sh

🖥️ Main Menu Options
text

1) Install Dependencies
2) Update Geo Files (Iran + Optional)
3) Configure Passwall2 with Xray  
4) Harden Firewall
5) Setup DNS over HTTPS
6) Verify Installation
7) Experimental Optimizations ⚠️
8) Run Complete Setup (Recommended)
0) Exit

🌟 Key Highlights
Geo File Management

    Default Iran routing rules

    Optional additions for China/Russia

    Custom country support

    Automatic rule generation

bash

Select countries to include:
1) Iran (ir)
2) China (cn) 
3) Russia (ru)
4) Custom countries

Safety Features

    Automatic backups before changes

    Detailed verification reports

    Experimental features clearly marked

    One-click rollback capability

⚠️ Experimental Features

The script includes optional network optimizations marked as experimental:

    Adaptive TCP buffer sizing

    Connection-specific tuning

    Automatic hardware detection

To access:
bash

Choose option 7 from main menu

🔄 Rollback Instructions

    For firewall changes:
    bash

cp /etc/config/firewall.bak /etc/config/firewall
/etc/init.d/firewall restart

For network settings:
bash

    cp /etc/sysctl.conf.bak /etc/sysctl.conf
    sysctl -p

📊 Verification Output Example
text

Xray installed: Xray 1.8.4 (Xray, Penetrates Everything.)
Passwall status: running
Geo files: /usr/share/xray/geoip.dat (v20230315)
DNS: Using DoH (cloudflare-dns.com)

🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.
📜 License

MIT
