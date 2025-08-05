#!/bin/sh

# Color Definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# Configuration
CONFIG_BACKUP_DIR="/etc/config/backup-helper"
MAX_BACKUPS=5
LOG_FILE="/tmp/openwrt-manager.log"

# Passwall2 Repositories
REPO1="https://downloads.sourceforge.net/project/openwrt-passwall-build/releases/packages"
REPO2="https://github.com/xiaorouji/openwrt-passwall/releases/download/packages"
REPO3="https://op.supes.top/packages"

# Initialize
mkdir -p "$CONFIG_BACKUP_DIR" || echo "Failed to create backup directory" >&2
touch "$LOG_FILE" || echo "Failed to create log file" >&2

# Logging Function
log() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$timestamp - $1" >> "$LOG_FILE"
  case "$2" in
    "red") echo -e "${RED}[✘] $1${NC}" ;;
    "green") echo -e "${GREEN}[✔] $1${NC}" ;;
    "yellow") echo -e "${YELLOW}[!] $1${NC}" ;;
    *) echo -e "${BLUE}[i] $1${NC}" ;;
  esac
}

show_header() {
  clear
  echo -e "${CYAN}================================================"
  echo -e "   OpenWrt VPN/Firewall Management System"
  echo -e "================================================${NC}"
}

pause() {
  echo ""
  echo -e "${YELLOW}Press ENTER to continue...${NC}"
  read -r
}

check_dependencies() {
  local missing=""
  for cmd in uci opkg ipset pgrep wget; do
    if ! command -v "$cmd" >/dev/null; then
      missing="$missing $cmd"
    fi
  done
  
  if [ -n "$missing" ]; then
    log "Missing required commands:$missing" "red"
    return 1
  fi
  return 0
}

check_internet() {
  log "Checking internet connection..." "blue"
  if ping -c1 -W3 8.8.8.8 >/dev/null 2>&1; then
    log "Internet connection detected" "green"
    return 0
  else
    log "No internet connection detected" "red"
    return 1
  fi
}

restart_service() {
  local service="$1"
  if [ -f "/etc/init.d/$service" ]; then
    log "Restarting $service..." "blue"
    if /etc/init.d/"$service" restart >/dev/null 2>&1; then
      log "Service restarted successfully" "green"
      return 0
    else
      log "Failed to restart service" "red"
      return 1
    fi
  else
    log "Service $service not found" "red"
    return 1
  fi
}

check_status() {
  show_header
  echo -e "${BLUE}=== System Status Check ===${NC}"
  
  if [ -f "/etc/init.d/passwall2" ]; then
    if pgrep -f passwall2 >/dev/null; then
      log "Passwall2 is installed and running" "green"
    else
      log "Passwall2 is installed but not running" "yellow"
    fi
  else
    log "Passwall2 is not installed" "red"
  fi

  if pgrep -f xray >/dev/null; then
    log "Xray process is running" "green"
  else
    log "Xray process is not running" "red"
  fi

  if ipset list banip >/dev/null 2>&1; then
    log "BanIP IP set is active" "green"
  else
    log "BanIP IP set is not active" "red"
  fi

  if grep -q banip /etc/config/firewall; then
    log "Firewall rules for BanIP exist" "green"
  else
    log "No firewall rules for BanIP found" "red"
  fi

  pause
}

backup_configs() {
  show_header
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_dir="$CONFIG_BACKUP_DIR/$timestamp"
  
  log "Creating backup directory: $backup_dir" "blue"
  if ! mkdir -p "$backup_dir"; then
    log "Failed to create backup directory" "red"
    pause
    return 1
  fi
  
  log "Starting configuration backup..." "blue"
  local backup_failed=0
  
  # List of configuration files to backup
  local config_files="passwall2 firewall banip network"
  
  for config in $config_files; do
    if [ -f "/etc/config/$config" ]; then
      if cp "/etc/config/$config" "$backup_dir/$config.bak"; then
        log "Backed up $config successfully" "green"
      else
        log "Failed to backup $config" "red"
        backup_failed=1
      fi
    else
      log "Config file $config not found, skipping" "yellow"
    fi
  done
  
  # Backup rotation
  local backup_count=$(ls -d "$CONFIG_BACKUP_DIR"/*/ 2>/dev/null | wc -l)
  if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
    log "Rotating old backups (keeping $MAX_BACKUPS)" "blue"
    ls -dt "$CONFIG_BACKUP_DIR"/*/ | tail -n +$((MAX_BACKUPS+1)) | xargs rm -rf 2>/dev/null
  fi
  
  if [ "$backup_failed" -eq 0 ]; then
    log "Backup completed successfully in $backup_dir" "green"
  else
    log "Backup completed with some errors" "yellow"
  fi
  
  pause
}

restore_configs() {
  show_header
  local latest_backup=$(ls -dt "$CONFIG_BACKUP_DIR"/*/ 2>/dev/null | head -1)
  
  if [ -z "$latest_backup" ]; then
    log "No backup files found to restore" "red"
    pause
    return 1
  fi
  
  log "Found backup: $latest_backup" "blue"
  echo -e "${YELLOW}WARNING: This will overwrite current configurations!${NC}"
  read -p "Are you sure you want to restore? [y/N]: " confirm
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log "Restore cancelled by user" "yellow"
    pause
    return
  fi
  
  log "Restoring configurations from backup..." "blue"
  
  local restore_failed=0
  for config_file in "$latest_backup"/*.bak; do
    if [ -f "$config_file" ]; then
      local config_name=$(basename "$config_file" .bak)
      if cp "$config_file" "/etc/config/$config_name"; then
        log "Restored $config_name successfully" "green"
      else
        log "Failed to restore $config_name" "red"
        restore_failed=1
      fi
    fi
  done
  
  # Restart services
  restart_service firewall
  [ -f "/etc/init.d/passwall2" ] && restart_service passwall2
  
  if [ "$restore_failed" -eq 0 ]; then
    log "Configuration restore completed successfully" "green"
  else
    log "Configuration restore completed with some errors" "yellow"
  fi
  
  pause
}

install_banip_ipset() {
  show_header
  check_internet || { pause; return; }
  
  log "Updating package lists..." "blue"
  if opkg update >/dev/null 2>&1; then
    log "Package lists updated successfully" "green"
  else
    log "Failed to update package lists" "red"
    pause
    return 1
  fi
  
  log "Installing BanIP and ipset..." "blue"
  if opkg install ipset banip >/dev/null 2>&1; then
    log "BanIP installed successfully" "green"
    /etc/init.d/banip enable && /etc/init.d/banip start
    log "BanIP service enabled and started" "green"
  else
    log "Failed to install BanIP" "red"
    pause
    return 1
  fi
  
  pause
}

add_banip_firewall_rules() {
  show_header
  log "Adding BanIP firewall rule..." "blue"
  
  uci add firewall rule
  uci set firewall.@rule[-1].name='BanIP Block'
  uci set firewall.@rule[-1].src='lan'
  uci set firewall.@rule[-1].dest='wan'
  uci set firewall.@rule[-1].ipset='banip'
  uci set firewall.@rule[-1].target='REJECT'
  
  if uci commit firewall; then
    restart_service firewall
    log "BanIP firewall rule added successfully" "green"
  else
    log "Failed to add BanIP firewall rule" "red"
  fi
  
  pause
}

remove_banip_rules() {
  show_header
  log "Removing BanIP firewall rules..." "blue"
  
  local removed=0
  uci show firewall | grep "=rule" | cut -d. -f2 | while read -r id; do
    name=$(uci get firewall."$id".name 2>/dev/null)
    if [ "$name" = "BanIP Block" ]; then
      uci delete firewall."$id"
      removed=1
    fi
  done
  
  if [ "$removed" -eq 1 ]; then
    uci commit firewall
    restart_service firewall
    log "BanIP firewall rules removed successfully" "green"
  else
    log "No BanIP firewall rules found to remove" "yellow"
  fi
  
  pause
}

remove_banip_ipset() {
  show_header
  log "Removing BanIP..." "blue"
  
  if [ -f "/etc/init.d/banip" ]; then
    /etc/init.d/banip stop
    /etc/init.d/banip disable
    log "BanIP service stopped and disabled" "green"
  else
    log "BanIP service not found" "yellow"
  fi
  
  log "Uninstalling BanIP packages..." "blue"
  if opkg remove --autoremove banip ipset >/dev/null 2>&1; then
    log "BanIP packages removed successfully" "green"
  else
    log "Failed to remove BanIP packages" "red"
  fi
  
  pause
}

full_uninstall() {
  show_header
  log "Starting full uninstall..." "blue"
  
  remove_banip_rules
  remove_banip_ipset
  restore_configs
  
  log "Full uninstall completed" "green"
  pause
}

passwall_repo_menu() {
  show_header
  echo -e "${CYAN}=== Passwall2 Repository Selection ===${NC}"
  echo -e "1) SourceForge (Official)"
  echo -e "2) GitHub (xiaorouji)"
  echo -e "3) OpenWrt Supes Top"
  echo -e "4) Back to Main Menu"
  echo -e "${CYAN}======================================${NC}"
  echo -n "Enter your choice (1-4): "
  read -r choice
  
  case "$choice" in
    1) install_from_repo "$REPO1" ;;
    2) install_from_repo "$REPO2" ;;
    3) install_from_repo "$REPO3" ;;
    4) return ;;
    *) 
      log "Invalid selection" "red"
      pause
      passwall_repo_menu
      ;;
  esac
}

install_from_repo() {
  local repo_base="$1"
  
  if [ -f "/etc/init.d/passwall2" ]; then
    log "Passwall2 is already installed" "yellow"
    echo -e "${YELLOW}Do you want to reinstall? [y/N]: ${NC}"
    read -r reinstall
    if [ "$reinstall" != "y" ] && [ "$reinstall" != "Y" ]; then
      pause
      passwall_repo_menu
      return
    fi
  fi
  
  log "Preparing system for Passwall2 installation from $repo_base..." "blue"
  
  # Remove dnsmasq if installed
  if opkg list-installed | grep -q "^dnsmasq "; then
    log "Removing dnsmasq..." "blue"
    if opkg remove dnsmasq >/dev/null 2>&1; then
      log "dnsmasq removed successfully" "green"
    else
      log "Failed to remove dnsmasq" "red"
      pause
      passwall_repo_menu
      return
    fi
  fi
  
  # Install dependencies
  log "Installing required dependencies..." "blue"
  if opkg install dnsmasq-full kmod-nft-tproxy kmod-nft-socket >/dev/null 2>&1; then
    log "Dependencies installed successfully" "green"
  else
    log "Failed to install dependencies" "red"
    pause
    passwall_repo_menu
    return
  fi
  
  # Get system info
  release=$(grep 'DISTRIB_RELEASE' /etc/openwrt_release | cut -d= -f2 | tr -d "'")
  release=${release%.*}
  arch=$(grep 'DISTRIB_ARCH' /etc/openwrt_release | cut -d= -f2 | tr -d "'")
  
  log "Configuring Passwall2 repository for OpenWrt $release $arch..." "blue"
  
  # Configure feeds
  echo "src/gz passwall_packages $repo_base/packages-$release/$arch/passwall_packages" > /etc/opkg/customfeeds.conf
  echo "src/gz passwall2 $repo_base/packages-$release/$arch/passwall2" >> /etc/opkg/customfeeds.conf
  
  # Add repository key
  log "Adding repository key..." "blue"
  if wget -O /tmp/passwall.pub "$repo_base/passwall.pub" >/dev/null 2>&1; then
    if opkg-key add /tmp/passwall.pub >/dev/null 2>&1; then
      log "Repository key added successfully" "green"
    else
      log "Failed to add repository key" "red"
      pause
      passwall_repo_menu
      return
    fi
  else
    log "Failed to download repository key" "red"
    pause
    passwall_repo_menu
    return
  fi
  
  # Update packages
  log "Updating package lists..." "blue"
  if opkg update >/dev/null 2>&1; then
    log "Package lists updated successfully" "green"
  else
    log "Failed to update package lists" "red"
    pause
    passwall_repo_menu
    return
  fi
  
  # Install Passwall2
  log "Installing Passwall2..." "blue"
  if opkg install luci-app-passwall2 >/dev/null 2>&1; then
    /etc/init.d/passwall2 enable
    /etc/init.d/passwall2 start
    log "Passwall2 installed and started successfully" "green"
  else
    log "Failed to install Passwall2" "red"
  fi
  
  pause
  passwall_repo_menu
}

install_useful_luci_apps() {
  show_header
  check_internet || { pause; return; }
  
  echo -e "${CYAN}=== Available LuCI Apps ===${NC}"
  echo -e "1) luci-app-banip"
  echo -e "2) luci-app-statistics"
  echo -e "3) luci-app-nlbwmon"
  echo -e "4) luci-app-upnp"
  echo -e "5) All of the above"
  echo -e "6) Back to Main Menu"
  echo -e "${CYAN}==========================${NC}"
  echo -n "Select apps to install (1-6): "
  read -r choice
  
  case "$choice" in
    1) apps="luci-app-banip" ;;
    2) apps="luci-app-statistics" ;;
    3) apps="luci-app-nlbwmon" ;;
    4) apps="luci-app-upnp" ;;
    5) apps="luci-app-banip luci-app-statistics luci-app-nlbwmon luci-app-upnp" ;;
    6) return ;;
    *) 
      log "Invalid selection" "red"
      pause
      install_useful_luci_apps
      return
      ;;
  esac
  
  log "Installing selected LuCI apps..." "blue"
  for app in $apps; do
    if opkg install "$app" >/dev/null 2>&1; then
      log "$app installed successfully" "green"
    else
      log "Failed to install $app" "red"
    fi
  done
  
  pause
  install_useful_luci_apps
}

add_geoip_rules() {
  show_header
  log "Adding GeoIP firewall rules..." "blue"
  
  # Remove existing rules first
  remove_geoip_rules
  
  # Add Iran Direct rule
  uci add firewall rule
  uci set firewall.@rule[-1].name='Iran Direct'
  uci set firewall.@rule[-1].src='lan'
  uci set firewall.@rule[-1].dest='wan'
  uci set firewall.@rule[-1].ipset='ir'
  uci set firewall.@rule[-1].target='ACCEPT'
  uci set firewall.@rule[-1].family='ipv4'
  
  if uci commit firewall; then
    restart_service firewall
    log "GeoIP firewall rules added successfully" "green"
  else
    log "Failed to add GeoIP firewall rules" "red"
  fi
  
  pause
}

remove_geoip_rules() {
  local removed=0
  while true; do
    local id=$(uci show firewall | grep -E "firewall\.@rule\[[0-9]+\]\.name='Iran Direct'" | cut -d. -f2 | cut -d[ -f2 | cut -d] -f1 | head -1)
    [ -z "$id" ] && break
    
    uci delete firewall.@rule["$id"]
    removed=1
  done
  
  if [ "$removed" -eq 1 ]; then
    uci commit firewall
  fi
}

main_menu() {
  while true; do
    show_header
    echo -e "${CYAN}=== Main Menu ===${NC}"
    echo -e "1) System Status Check"
    echo -e "2) Backup Configurations"
    echo -e "3) Install/Fix BanIP"
    echo -e "4) Add BanIP Firewall Rules"
    echo -e "5) Remove BanIP Rules"
    echo -e "6) Remove BanIP IPset"
    echo -e "7) Restore Configurations"
    echo -e "8) Full Uninstall"
    echo -e "9) Install Passwall2"
    echo -e "10) Install LuCI Apps"
    echo -e "11) Add GeoIP Rules"
    echo -e "12) View Log"
    echo -e "13) Exit"
    echo -e "${CYAN}==========================${NC}"
    echo -n "Enter your choice (1-13): "
    read -r choice
    
    case "$choice" in
      1) check_status ;;
      2) backup_configs ;;
      3) install_banip_ipset ;;
      4) add_banip_firewall_rules ;;
      5) remove_banip_rules ;;
      6) remove_banip_ipset ;;
      7) restore_configs ;;
      8) full_uninstall ;;
      9) passwall_repo_menu ;;
      10) install_useful_luci_apps ;;
      11) add_geoip_rules ;;
      12) less "$LOG_FILE" ;;
      13) exit 0 ;;
      *) 
        echo -e "${RED}Invalid option!${NC}"
        pause
        ;;
    esac
  done
}

# Start the script
main_menu