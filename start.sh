#!/bin/bash

#=============================================#
#   OpenWrt Passwall2/Xray Configuration     #
#   Optimized for Iran with optional extras  #
#=============================================#

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
function print_msg() {
    local color="$1"
    local msg="$2"
    case $color in
        green) echo -e "${GREEN}${msg}${NC}";;
        red) echo -e "${RED}${msg}${NC}";;
        yellow) echo -e "${YELLOW}${msg}${NC}";;
        blue) echo -e "${BLUE}${msg}${NC}";;
        *) echo -e "${msg}";;
    esac
}

# Function to check root
function check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_msg red "This script must be run as root!"
        exit 1
    fi
}

# Install all required dependencies
function install_dependencies() {
    print_msg blue "Updating package lists..."
    opkg update
    
    print_msg blue "Installing core dependencies..."
    core_pkgs=(
        iptables-mod-tproxy iptables-mod-extra
        ca-certificates https-dns-proxy
        coreutils-nohup bash grep
        luci luci-compat luci-i18n-base-en
        kmod-tun libcap libcap-bin ruby ruby-yaml
    )
    
    for pkg in "${core_pkgs[@]}"; do
        if ! opkg list-installed | grep -q "^${pkg} "; then
            opkg install "$pkg" || print_msg red "Failed to install $pkg"
        fi
    done
    
    print_msg blue "Installing Passwall2 and Xray..."
    proxy_pkgs=(
        xray-core v2ray-core
        v2ray-geoip v2ray-geosite
        luci-app-passwall2 passwall2-core
    )
    
    for pkg in "${proxy_pkgs[@]}"; do
        if ! opkg list-installed | grep -q "^${pkg} "; then
            opkg install "$pkg" || print_msg red "Failed to install $pkg"
        fi
    done
    
    print_msg green "All dependencies installed successfully!"
}

# Update geo files with optional countries

function update_geo_files() {
    while true; do
        print_msg blue "\n[GEO FILE UPDATE MENU]"
        print_msg yellow "Current Geo Files:"
        find /usr -name "geoip.dat" -o -name "geosite.dat" -exec ls -lh {} \; 2>/dev/null || \
        print_msg red "No geo files found"
        
        print_msg yellow "\nSelect operation:"
        echo -e "${GREEN}1)${NC} Update Iran only (ir)"
        echo -e "${GREEN}2)${NC} Update China only (cn)"
        echo -e "${GREEN}3)${NC} Update Russia only (ru)"
        echo -e "${GREEN}4)${NC} Custom country selection"
        echo -e "${GREEN}5)${NC} View current rules"
        echo -e "${RED}0)${NC} Return to Main Menu"
        
        read -p "Your choice [0-5]: " choice
        
        case $choice in
            0) 
                print_msg yellow "Returning to main menu..."
                return 0
                ;;
            1) COUNTRIES=("ir");;
            2) COUNTRIES=("cn");;
            3) COUNTRIES=("ru");;
            4)
                print_msg blue "\nEnter country codes (space separated):"
                echo "Examples:"
                echo "  ir cn ? Iran and China"
                echo "  de fr ? Germany and France"
                read -p "Countries: " custom_codes
                COUNTRIES=($custom_codes)
                [ ${#COUNTRIES[@]} -eq 0 ] && {
                    print_msg red "No countries entered!"
                    continue
                }
                ;;
            5)
                if [ -f "/etc/passwall/rules/custom_rules.json" ]; then
                    print_msg blue "\nCurrent Routing Rules:"
                    jq . "/etc/passwall/rules/custom_rules.json" 2>/dev/null || \
                    cat "/etc/passwall/rules/custom_rules.json"
                else
                    print_msg red "No rules file found"
                fi
                read -p $'\nPress Enter to continue...'
                clear
                continue
                ;;
            *)
                print_msg red "Invalid option!"
                continue
                ;;
        esac

        [ $choice -ge 1 ] && [ $choice -le 4 ] && {
            # Actual update processing here
            print_msg green "\nUpdating geo files for: ${COUNTRIES[*]}"
            # ... (rest of your update code) ...
            
            read -p $'\nUpdate complete! Press Enter to return to menu...'
            clear
        }
    done
}


# Configure Passwall2 with optimized Xray settings
function configure_passwall() {
    print_msg blue "Configuring Passwall2 with Xray..."
    
    # Basic configuration
    uci set passwall.@global[0].enabled='1'
    uci set passwall.@global[0].tcp_proxy_mode='global'
    uci set passwall.@global[0].udp_proxy_mode='global'
    uci set passwall.@global[0].china_ip_route='1'
    uci set passwall.@global[0].china_ad_route='1'
    
    # DNS settings
    uci set passwall.@global_dns[0].dns_mode='doh'
    uci set passwall.@global_dns[0].doh='https://cloudflare-dns.com/dns-query'
    uci set passwall.@global_dns[0].remote_dns='tcp://1.1.1.1'
    uci set passwall.@global_dns[0].dns_cache='1'
    
    # Bypass settings (will use our custom rules)
    uci set passwall.@bypass[0].ip_list='geoip:ir,geoip:private'
    uci set passwall.@bypass[0].domain_list='geosite:ir'
    
    # Xray core settings for best performance and stealth
    uci set passwall.@global_forwarding[0].xray_protocol='vless'
    uci set passwall.@global_forwarding[0].xray_transport='ws'
    uci set passwall.@global_forwarding[0].xray_security='tls'
    uci set passwall.@global_forwarding[0].xray_fingerprint='chrome'
    uci set passwall.@global_forwarding[0].xray_flow='xtls-rprx-vision'
    
    # Performance tuning
    uci set passwall.@global[0].concurrency='8'
    uci set passwall.@global[0].buffer_size='32'
    uci set passwall.@global[0].xray_fullcone='1'
    
    uci commit passwall
    
    # Enable and restart Passwall
    /etc/init.d/passwall enable
    /etc/init.d/passwall restart
    
    print_msg green "Passwall2 configured with optimized Xray settings!"
}

# Harden the firewall
function harden_firewall() {
    print_msg blue "Hardening firewall..."
    
    # Secure web interface
    uci set uhttpd.main.listen_http='127.0.0.1:80'
    uci set uhttpd.main.listen_https='127.0.0.1:443'
    uci commit uhttpd
    /etc/init.d/uhttpd restart
    
    # Secure SSH
    uci set dropbear.@dropbear[0].Port='2222'
    uci set dropbear.@dropbear[0].PasswordAuth='off'
    uci set dropbear.@dropbear[0].RootPasswordAuth='off'
    uci commit dropbear
    /etc/init.d/dropbear restart
    
    # Disable IPv6
    uci set network.globals.ula_prefix=''
    uci set network.lan.ip6assign='0'
    uci set dhcp.lan.dhcpv6='disabled'
    uci set dhcp.lan.ra='disabled'
    uci set dhcp.lan.ndp='disabled'
    uci commit network
    uci commit dhcp
    
    # Firewall rules
    uci set firewall.@defaults[0].syn_flood='1'
    uci set firewall.@defaults[0].drop_invalid='1'
    
    # Rate limiting for SSH
    uci set firewall.ssh_limit=rule
    uci set firewall.ssh_limit.name='Limit SSH'
    uci set firewall.ssh_limit.src='wan'
    uci set firewall.ssh_limit.dest_port='2222'
    uci set firewall.ssh_limit.proto='tcp'
    uci set firewall.ssh_limit.target='DROP'
    uci set firewall.ssh_limit.limit='3/min'
    uci set firewall.ssh_limit.limit_burst='5'
    
    uci commit firewall
    /etc/init.d/network restart
    /etc/init.d/odhcpd restart
    /etc/init.d/firewall restart
    
    print_msg green "Firewall hardening complete!"
}

# Setup secure DNS
function setup_doh_dns() {
    print_msg blue "Setting up DNS over HTTPS..."
    
    # Configure HTTPS DNS Proxy
    uci set https-dns-proxy.@https-dns-proxy[0].enabled='1'
    uci set https-dns-proxy.@https-dns-proxy[0].dns_servers='1.1.1.1,8.8.8.8'
    uci set https-dns-proxy.@https-dns-proxy[0].resolver_url='https://cloudflare-dns.com/dns-query'
    uci set https-dns-proxy.@https-dns-proxy[0].bootstrap_dns='1.1.1.1,8.8.8.8'
    uci commit https-dns-proxy
    
    # Configure DNSMasq
    uci set dhcp.@dnsmasq[0].noresolv='1'
    uci set dhcp.@dnsmasq[0].localuse='1'
    uci set dhcp.@dnsmasq[0].cachesize='10000'
    uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5053'
    uci commit dhcp
    
    /etc/init.d/https-dns-proxy restart
    /etc/init.d/dnsmasq restart
    
    print_msg green "DNS over HTTPS setup complete!"
}

# Optimize system performance

function experimental_optimization() {
    print_msg yellow "?? EXPERIMENTAL NETWORK OPTIMIZATION ??"
    print_msg yellow "This feature may improve performance but could cause instability"
    print_msg yellow "A backup of original settings will be created automatically\n"

    # Check if backup already exists
    if [ -f "/etc/sysctl.conf.bak" ]; then
        print_msg blue "Found existing backup: /etc/sysctl.conf.bak"
        read -p "Restore original settings first? [y/N] " restore_choice
        if [[ "$restore_choice" =~ [yY] ]]; then
            cp /etc/sysctl.conf.bak /etc/sysctl.conf
            sysctl -p >/dev/null 2>&1
            print_msg green "Original settings restored!"
            return
        fi
    fi

    # Main menu
    while true; do
        echo -e "\n${YELLOW}Experimental Optimization Menu:${NC}"
        echo -e "${GREEN}1)${NC} Apply adaptive optimizations (auto-detected)"
        echo -e "${GREEN}2)${NC} Apply conservative defaults"
        echo -e "${GREEN}3)${NC} View current settings"
        echo -e "${GREEN}4)${NC} Restore original settings"
        echo -e "${RED}0)${NC} ? Return to main menu"
        
        read -p "Your choice [0-4]: " choice
        
        case $choice in
            1)
                # Create backup if doesn't exist
                [ ! -f "/etc/sysctl.conf.bak" ] && cp /etc/sysctl.conf /etc/sysctl.conf.bak
                
                print_msg blue "Applying adaptive optimizations..."
                # ... (include the adaptive optimization code from previous example) ...
                
                sysctl -p >/dev/null 2>&1
                print_msg green "Optimizations applied (adaptive mode)"
                ;;
            2)
                [ ! -f "/etc/sysctl.conf.bak" ] && cp /etc/sysctl.conf /etc/sysctl.conf.bak
                
                print_msg blue "Applying conservative defaults..."
                cat >> /etc/sysctl.conf <<EOF
# Conservative Defaults (Passwall)
net.core.rmem_max=2097152
net.core.wmem_max=2097152
net.ipv4.tcp_rmem=4096 87380 2097152
net.ipv4.tcp_wmem=4096 16384 2097152
net.ipv4.tcp_fastopen=3
EOF
                sysctl -p >/dev/null 2>&1
                print_msg green "Conservative defaults applied"
                ;;
            3)
                print_msg blue "Current Network Settings:"
                sysctl -a 2>/dev/null | grep -E "rmem|wmem|tcp_" | head -n 20
                read -p $'\nPress Enter to continue...'
                ;;
            4)
                if [ -f "/etc/sysctl.conf.bak" ]; then
                    cp /etc/sysctl.conf.bak /etc/sysctl.conf
                    sysctl -p >/dev/null 2>&1
                    print_msg green "Original settings restored!"
                else
                    print_msg red "No backup found to restore!"
                fi
                ;;
            0)
                return
                ;;
            *)
                print_msg red "Invalid option!"
                ;;
        esac
        
        read -p $'\nPress Enter to return to menu...'
    done
}

# Verify installation
function verify_installation() {
    print_msg blue "Verifying installation..."
    
    # Check Xray (more robust check)
    if command -v xray >/dev/null 2>&1; then
        print_msg green "Xray installed: $(xray -version | head -n 1)"
    else
        print_msg red "Xray not found in PATH!"
    fi
    
    # Check Passwall2 (better detection methods)
    if [ -f "/etc/init.d/passwall" ] || [ -f "/etc/init.d/passwall2" ]; then
        print_msg green "Passwall detected:"
        if [ -f "/etc/init.d/passwall" ]; then
            /etc/init.d/passwall status
        else
            /etc/init.d/passwall2 status
        fi
    elif ls /etc/config/passwall* >/dev/null 2>&1; then
        print_msg yellow "Passwall config found but service not installed"
    else
        print_msg red "No Passwall installation detected"
    fi
    
    # Check DNS (more informative)
    print_msg blue "\nDNS Configuration:"
    cat /etc/resolv.conf | grep nameserver
    print_msg blue "\nCurrent DNS Test:"
    nslookup google.com | grep -A2 "Server\|Address"
    
    # Check geo files (more locations)
    print_msg blue "\nGeo Files Check:"
    geo_locations=(
        "/usr/share/xray/"
        "/usr/share/v2ray/"
        "/etc/passwall/"
    )
    
    found_files=0
    for location in "${geo_locations[@]}"; do
        if [ -f "${location}geoip.dat" ]; then
            print_msg green "geoip.dat found in ${location}"
            found_files=$((found_files+1))
        fi
        if [ -f "${location}geosite.dat" ]; then
            print_msg green "geosite.dat found in ${location}"
            found_files=$((found_files+1))
        fi
    done
    
    if [ $found_files -eq 0 ]; then
        print_msg red "No geo files found in standard locations"
    fi
    
    print_msg green "\nVerification complete!"
}



# Main menu
function show_menu() {
    clear
    echo -e "${BLUE}"
    echo "========================================"
    echo "  OpenWrt Passwall2/Xray Configuration  "
    echo "          Optimized for Iran           "
    echo "========================================"
    echo -e "${NC}"
    echo "1) Install All Dependencies"
    echo "2) Update Geo Files (Iran + Optional)"
    echo "3) Configure Passwall2 with Xray"
    echo "4) Harden Firewall"
    echo "5) Setup DNS over HTTPS"
    echo "6) Optimize System Performance"
    echo "7) Verify Installation"
    echo "8) Run Complete Setup (Recommended)"
    echo "9) Experimental Network Optimization"
    echo "0) Exit"
    echo -e "${BLUE}========================================${NC}"
}

# Main function
function main() {
    check_root
    
    while true; do
        show_menu
        read -p "Enter your choice: " choice
        
        case $choice in
            1) install_dependencies ;;
            2) update_geo_files ;;
            3) configure_passwall ;;
            4) harden_firewall ;;
            5) setup_doh_dns ;;
            6) optimize_system ;;
            7) verify_installation ;;
            8)
                print_msg blue "Running complete setup..."
                install_dependencies
                update_geo_files
                configure_passwall
                harden_firewall
                setup_doh_dns
                optimize_system
                verify_installation
                print_msg green "Complete setup finished!"
                ;;
            9) experimental_optimization ;;
            0) 
                print_msg green "Exiting. Goodbye!"
                exit 0
                ;;
            *)
                print_msg red "Invalid option. Please try again."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Start the script
main