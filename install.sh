#!/bin/bash -e

BOOTSTRAPPER_NAME="Raspberry Pi WiFi Tetherer"
BOOTSTRAPPER_VERSION="1.0.0"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

print_error() {
  printf "\033[0;31m$1\033[0m\n"
}

print_warning() {
  printf "\033[1;33m$1\033[0m\n"
}

print_success() {
  printf "\033[0;32m$1\033[0m\n"
}

print_info() {
  printf "\033[1;36m$1\033[0m\n"
}

error_exit() {
  print_error "\nError: $1" 1>&2
  print_error "Exiting.\n" 1>&2
  exit 1
}

check_root() {
  if [ $EUID -ne 0 ]; then
    error_exit "Root privileges required. Please run as root."
  fi
}


usage () {
  printf "$BOOTSTRAPPER_NAME\n"
  printf "Version $BOOTSTRAPPER_VERSION\n\n"

  printf "Usage:\n"
  printf "  $0 [-u <username>] [-p <password>] [-s <SSID>] [-w <wifi_password>]\n"
  exit 1
}

parse_args() {
  OPTIND=1
  while getopts ":u:p:s:w:" opt; do
    case "$opt" in
      u)  USERNAME=$OPTARG ;;
      p)  PASSWORD=$OPTARG ;;
      s)  SSID=$OPTARG ;;
      w)  WIFI_PASSWORD=$OPTARG ;;
      \?) usage ;;
    esac
  done
  shift $((OPTIND-1))

  if [ -z "$USERNAME" ]; then
    until [[ -n "$USERNAME" ]]; do
      read -e -r -p "Local username -> " USERNAME
    done
    echo
  fi

  if [ -z "$PASSWORD" ]; then
    until [[ "$PASSWORD" == "$PASSWORD2" ]] && [[ -n "$PASSWORD" ]]; do
      unset PASSWORD PASSWORD2
      until [[ -n "$PASSWORD" ]]; do
        read -e -r -s -p "Local user password (input hidden) -> " PASSWORD && echo
      done
      read -e -r -s -p "Verify password (input hidden)     -> " PASSWORD2 && echo
      [ "$PASSWORD" == "$PASSWORD2" ] || print_error "Passwords do not match. Please try again."
    done
    echo
  fi

  if [ -z "$SSID" ]; then
    until [[ -n "$SSID" ]]; do
      read -e -r -p "WiFi SSID -> " SSID
    done
    echo
  fi

  if [ -z "$WIFI_PASSWORD" ]; then
    until [[ "$WIFI_PASSWORD" == "$WIFI_PASSWORD2" ]] && [[ -n "$WIFI_PASSWORD" ]]; do
      unset WIFI_PASSWORD WIFI_PASSWORD2
      until [[ -n "$WIFI_PASSWORD" ]]; do
        read -e -r -s -p "WiFi password (input hidden)   -> " WIFI_PASSWORD && echo
      done
      read -e -r -s -p "Verify password (input hidden) -> " WIFI_PASSWORD2 && echo
      [ "$WIFI_PASSWORD" == "$WIFI_PASSWORD2" ] || print_error "Passwords do not match. Please try again."
    done
    echo
  fi
}

prompt_continue() {
  echo
  print_warning "Please verify your settings."
  echo "Local user: $USERNAME"
  echo "WiFi SSID:  $SSID"
  echo
  read -p "Continue? [Y/n] " -r CONTINUE
  CONTINUE=${CONTINUE,,} # tolower
  if  ! [[ "$CONTINUE" =~ ^(yes|y)$ ]] && ! [[ -z "$CONTINUE" ]]; then
    error_exit "Aborted by user."
  fi
  printf "\n"
}


apt_update() {
  print_info "Updating system repositories..."
  rm -rf /var/lib/apt/lists &>/dev/null
  mkdir -p /var/lib/apt/lists/partial &>/dev/null
  apt-get update &>/dev/null
}

install_packages() {
  print_info "Installing packages..."
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
  apt-get install -y isc-dhcp-server iptables-persistent &>/dev/null
}

configure() {
  print_info "Configuring services..."
  cp "$DIR"/files/isc-dhcp-server /etc/default/isc-dhcp-server
  cp "$DIR"/files/dhcpd.conf /etc/dhcp/dhcpd.conf
  cp "$DIR"/files/dhcpcd.conf /etc/dhcpcd.conf
  cp "$DIR"/files/sysctl.conf /etc/sysctl.d/50-nat.conf
  cp "$DIR"/files/iptables-rules.v4 /etc/iptables/rules.v4

  export SSID
  export WIFI_PASSWORD
  envsubst < "$DIR"/files/wpa_supplicant.conf > /etc/wpa_supplicant/wpa_supplicant.conf
}

set_hostname() {
  print_info "Setting hostname..."
  hostnamectl set-hostname nat-pi
  cp "$DIR"/files/hosts /etc/hosts
}

user_add() {
  print_info "Configuring local user..."
  useradd -m -s /bin/bash "$USERNAME" &>/dev/null
  echo "$USERNAME:$PASSWORD" | chpasswd &>/dev/null
  usermod -a -G sudo "$USERNAME" &>/dev/null
  passwd -l pi &>/dev/null
}

check_root
parse_args "$@"
prompt_continue
apt_update
install_packages
configure
set_hostname
user_add

echo
print_success "Done! Please reboot to finish."
