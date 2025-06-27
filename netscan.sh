#!/bin/bash

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Check dependencies
check_dependencies() {
  echo -e "${CYAN}Checking dependencies...${NC}"
  for cmd in nmap tcpdump perl jq parallel; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo -e "${RED}Error:${NC} $cmd is not installed. Please install it."
      echo -e "Example: sudo apt-get update && sudo apt-get install nmap tcpdump perl jq parallel"
      exit 1
    fi
  done
}

# Ensure script is run as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root or with sudo.${NC}"
    exit 1
  fi
}

# Get interfaces (for interactive use)
get_interfaces() {
  echo -e "${CYAN}Available interfaces:${NC}"
  mapfile -t iface_list < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
  for i in "${!iface_list[@]}"; do
    printf "[%d] %s\n" "$((i+1))" "${iface_list[$i]}"
  done
  printf "[%d] all\n" "$(( ${#iface_list[@]} + 1 ))"

  read -p "Choose interface [1-$((${#iface_list[@]} + 1))]: " choice
  interfaces=()
  max_choice=$(( ${#iface_list[@]} + 1 ))

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#iface_list[@]} )); then
    interfaces=("${iface_list[$((choice-1))]}")
  elif [[ "$choice" == "all" ]] || (( choice == max_choice )); then
    interfaces=("${iface_list[@]}")
  else
    echo -e "${RED}Invalid choice.${NC}"
    exit 1
  fi
}

# Choose scan type (for interactive use)
choose_scan_type() {
  echo -e "\n${CYAN}Choose scan type:${NC}"
  echo "1) Standard (ping + nbstat)"
  echo "2) UDP port scan (top 1000)"
  echo "3) Listen for UDP multicast"
  read -p "Choice [1-3]: " scan_type
}

# Multicast scan
multicast_scan() {
  read -p "Duration for multicast sniff (seconds, default 30): " duration
  duration=${duration:-30}
  for iface in "${interfaces[@]}"; do
    echo -e "${CYAN}Listening on $iface...${NC}"
    timeout "$duration" tcpdump -i "$iface" -n multicast 2>/dev/null | \
      perl -n -e 'chomp; m/> (\d+\.\d+\.\d+\.\d+)\.(\d+)/; print "udp://$1:$2\n" if $1 && $2' | \
      sort | uniq | tee "multicast_$iface.log"
  done
  echo -e "${GREEN}Multicast capture saved to multicast_<iface>.log${NC}"
  exit 0
}

# Scan a single host and output a JSON object
scan_host() {
  local IP="$1"
  local output MAC HOSTNAME WG_DOMAIN MANUFACTURER

  # Run nmap once and store output
  output=$(nmap -sS -O --script nbstat.nse -p 137,139 "$IP" 2>/dev/null)

  # Extract data, providing 'N/A' as a fallback
  MAC=$(echo "$output" | grep 'MAC Address' | awk '{print $3}')
  HOSTNAME=$(echo "$output" | grep '<20>.*<unique>.*<active>' | awk -F'[|<]' '{print $2}' | tr -d '_' | xargs)
  WG_DOMAIN=$(echo "$output" | grep -v '<permanent>' | grep '<00>.*<group>.*<active>' | awk -F'[|<]' '{print $2}' | tr -d '_' | xargs)
  MANUFACTURER=$(echo "$output" | grep 'MAC Address' | awk -F'(' '{print $2}' | cut -d ')' -f1)

  # Create a clean JSON object for this host using jq
  jq -n \
    --arg ip "${IP:-N/A}" \
    --arg mac "${MAC:-N/A}" \
    --arg hostname "${HOSTNAME:-N/A}" \
    --arg wg_domain "${WG_DOMAIN:-N/A}" \
    --arg manufacturer "${MANUFACTURER:-N/A}" \
    '{ip: $ip, mac: $mac, hostname: $hostname, wg_domain: $wg_domain, manufacturer: $manufacturer}'
}
export -f scan_host

# Main scan execution
perform_scan() {
  if [[ "$scan_type" == "2" ]]; then
      echo -e "${RED}UDP scan not supported in this automated script version.${NC}"
      exit 1
  fi
  
  declare -a all_ips
  for iface in "${interfaces[@]}"; do
    ip_range=$(ip -o -f inet addr show "$iface" | awk '{print $4}' | head -n 1)
    if [ -z "$ip_range" ]; then
        echo -e "${YELLOW}Warning: Could not get IP range for $iface, skipping.${NC}" >&2
        continue
    fi
    echo -e "${CYAN}Discovering hosts on $ip_range ($iface)...${NC}" >&2
    mapfile -t iface_ips < <(nmap -sn "$ip_range" | awk '/Nmap scan report/{gsub(/[()]/,"",$NF); print $NF}')
    all_ips+=("${iface_ips[@]}")
  done

  # Get unique IPs
  IFS=$'\n' read -r -d '' -a unique_ips < <(printf "%s\n" "${all_ips[@]}" | sort -u && printf '\0')

  if [ ${#unique_ips[@]} -eq 0 ]; then
    echo -e "${YELLOW}No hosts found. Writing empty results file.${NC}" >&2
    echo "[]" > scan_results.json
    exit 0
  fi

  echo -e "${CYAN}Scanning ${#unique_ips[@]} hosts in parallel...${NC}" >&2

  # Run scans in parallel and pipe all JSON objects into jq to form a final JSON array
  results_json=$(parallel -j 10 scan_host ::: "${unique_ips[@]}" | jq -s '.')

  # Save the final, valid JSON file
  echo "$results_json" > scan_results.json

  echo -e "\n${GREEN}Scan complete.${NC} Results saved to ${YELLOW}scan_results.json${NC}" >&2
}

### Main Script Logic ###
check_dependencies
check_root

# If script is run with input redirection (from the API), run non-interactively.
# Otherwise, prompt the user for input.
if ! [ -t 0 ]; then
    read -r choice
    read -r scan_type
    if [[ "$choice" == "all" ]]; then
        mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    else
        interfaces=("$choice")
    fi
else
    get_interfaces
    choose_scan_type
fi

if [[ "$scan_type" == "3" ]]; then
    multicast_scan
else
    perform_scan
fi