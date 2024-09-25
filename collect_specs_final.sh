#!/bin/bash

# Function to display an error message and exit
function show_error() {
    dialog --msgbox "$1" 20 60
    exit 1
}

# Function to display a welcome message and exit
function welcome_msg(){
echo " ------------------------------------------------- "
echo "       ___ ___ ___ _____   ___  _   _ _  _____     "
echo "      / __| _ \ __/ __\ \ / /_\| | | | ||_   _|    "
echo "      \__ \  _/ _| (__ \ V / _ \ |_| | |__| |      "
echo "      |___/_| |___\___| \_/_/ \_\___/|____|_|      "
echo "                                                   "
echo " ------------------------------------------------- "
echo " SpecVault is an automated specfication collection "
echo " system that will read the hardware specs. It will "
echo " automatically upload the collected data to cloud  " 
echo " platform. Ensure you have proper connectivity to  "
echo " the Internet for successful uploading.            "
echo " Once data is successfully uploaded into the cloud,"
echo " visit https://specvault.cloud/login/ to review    "
echo " ------------------------------------------------- "
}

# Function to list the connected network interfaces
function list_interfaces() {
    local wlan_interface=$(ip link show | awk -F: '$0 ~ "wlan0"{print $2}' | tr -d ' ')
    if [ -n "$wlan_interface" ]; then
        local ip_address=$(ip -4 addr show "$wlan_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        local ssid=$(iwgetid -r)
        echo " ------- WLAN Connected ------- "
        echo " WLAN Interface: $wlan_interface"
        echo " IP Address: $ip_address"
        echo " Connected SSID: $ssid"
        echo " ------------------------------ "
    else
        local eth_interface=$(ip link show | awk -F: '$0 ~ "eth0"{print $2}' | tr -d ' ')
        if [ -n "$eth_interface" ]; then
            local ip_address=$(ip -4 addr show "$eth_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
            local gateway=$(ip route | grep default | awk '{print $3}')
            echo " ------- Ethernet Connected ------- "
            echo " Ethernet Interface: $eth_interface"
            echo " IP Address: $ip_address"
            echo " Default Gateway: $gateway"
            echo " ---------------------------------- " 
        else
             echo " ------- Error in Connection -------- "
             echo " No WLAN or Ethernet interface found. "
             echo " Ensure you are connected to Internet "
             echo " via WLAN or Eth, otherwise specs will"
             echo " be saved in a local file in the USB &"
             echo " will not be available in the cloud.  "
             echo " ------------------------------------ "
        fi
    fi
    check_connectivity
}

# Function to configure Wi-Fi
function configure_wifi() {
    local ssid password
    dialog --ascii-lines --msgbox "Scanning for available Wi-Fi networks..." 20 60
    available_ssids=$(nmcli dev wifi list | awk '{print $1}' | tail -n +2)
    ssid=$(dialog --menu "Select the Wi-Fi network:" 20 60 10 $available_ssids 2>&1 >/dev/tty)
    password=$(dialog --passwordbox "Enter the password for the Wi-Fi network ($ssid):" 20 60)

    # Connect to Wi-Fi
    if sudo nmcli device wifi connect "$ssid" password "$password"; then
        dialog --msgbox "Wi-Fi connected successfully!" 10 40
    else
        dialog --msgbox "Failed to connect to Wi-Fi." 10 40
    fi

    # Check connectivity
    check_connectivity
}

# Function to configure Ethernet
function configure_ethernet() {
    local chosen_interface="$1"
    sudo dhclient "$1"

    # Check connectivity
    check_connectivity
}

# Function to validate the chosen interface
function validate_interface() {
    local interface="$1"
    if [[ -z "$interface" ]]; then
        show_error "No interface selected."
    elif ! ip link show "$interface" &> /dev/null; then
        show_error "Invalid interface: $interface"
    fi
}

# Function to check internet connectivity
function check_connectivity() {
    # Your connectivity check logic here (e.g., ping)
    echo " ----- Checking Connectivity to Internet ----- "
    ping -c 4 8.8.8.8
    if [ $? -eq 0 ]; then
        echo " --------------------------------------------- "
        echo "                  SUCCESS                      "
        echo "       Internet Connectivity Confirmed         "
        echo "       PROCEEDING WITH SPECS COLLECTION        "
        echo " --------------------------------------------- "
        return 0
    else
        echo " --------------------------------------------- "
        echo "                   ERROR                       "
        echo "         Failed to connect to Internet         "
        echo "  PROCEEDING WITH LOCAL SAVING CAPABILITY ONLY "
        echo " --------------------------------------------- "        
        return 1
    fi
}

# Function to collect system specs
function collect_system_specs() {
    #dialog --ascii-lines --title "Collection in Progress" --msgbox "Collecting Specs for the System..." 20 60
    #lshw -short >> hardware.txt
    #lscpu >> hardware.txt
    inxi -Fxz >> specs.txt
    echo "Specs Collected in file specs.txt . . Now closing the program"
    exit 0
}

#Function to collect and Send to SQL DB
function collect_and_send() {

local lot_number="$1"

MYSQL_HOST="182.184.69.131"
MYSQL_USER="boltc"
MYSQL_PASSWORD="Abeeha@7864"
MYSQL_DATABASE="web_logics_db"

echo " ***** Collecting System Specifications ***** "
# Collect system specifications
HOSTNAME=$(hostname)
CPU=$(lscpu | grep 'Model name' | awk -F': ' '{print $2}')
#RAM=$(free -h | awk '/^Mem:/ {print $2}')
STORAGE=$(df -h | awk '$NF=="/" {print $2}')
#NETWORK_INTERFACE=$(ip link | awk -F': ' '$0 !~ "lo|vir|wl|^[^0-9]"{print $2; exit}')
NETWORK_INTERFACE=$(sudo lshw -class network | grep -E 'product' | awk -F': ' '{print $2}')
OS_VERSION=$(lsb_release -d | awk -F'\t' '{print $2}')

# Get GPU information using nvidia-smi (if available)
GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader)

# Check if any GPU (NVIDIA or non-NVIDIA) is available
if [ -z "$GPU_INFO" ]; then
    # No GPU detected
    GPU_INFO="No graphics card available"
fi

# Non-NVIDIA GPU information (if available)
NON_NVIDIA_GPU_INFO=$(lshw -C display | grep -i 'product' | grep -v 'NVIDIA' | awk -F': ' '{print $2}')
if [ -z "$NON_NVIDIA_GPU_INFO" ]; then
   NON_NVIDIA_GPU_INFO="NO VGA Compatible Display Adapter Available"
fi

# Get machine serial number
SERIAL_NUMBER=$(cat /sys/class/dmi/id/product_serial)

# Manufacturer or brand of the system
MANUFACTURER=$(dmidecode -s system-manufacturer)
MODEL_NUMBER=$(dmidecode -s system-product-name)

# Battery health (you can customize this based on your system)
BATTERY_HEALTH=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -i 'capacity' | awk '{print $2}')

# ---------- Find Display Size -----------------------------------
# Extract the width and height in millimeters
DISPLAY_SIZE=$(hwinfo --monitor | grep -i 'Size' | awk '{print $2}')
#HEIGHT=$(hwinfo --monitor | grep -i 'Size' | awk -F'[x]' '{print $3}')

# Calculate the diagonal size in millimeters
#DIAGONAL_MM=$(echo "scale=2; sqrt($WIDTH^2 + $HEIGHT^2)" | bc)

# Convert the diagonal size from millimeters to inches (1 inch = 25.4 mm)
#DIAGONAL_INCHES=$(echo "scale=2; $DIAGONAL_MM / 25.4" | bc)

# Extract the resolution
HORIZONTAL=$(hwinfo --monitor | grep -i 'Horizontal' | awk -F' ' '{print $2}')
VERTICAL=$(hwinfo --monitor | grep -i 'Vertical' | awk -F ' ' '{print$2}')
RESOLUTION=$("{$HORIZONTAL} x {$VERTICAL}")

# Combine the diagonal size and resolution into the DISPLAY_SIZE variable
#DISPLAY_SIZE="${DIAGONAL_INCHES} inches, Resolution: ${RESOLUTION}"
#----------------------------------------------------------------

# Hard disk information (including type and available slots)
HDD_INFO=$(lsblk -o NAME,MODEL | grep 'sd' | awk '{print $2}' | head -n 1)

# RAM type and size using free -h
#RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
#RAM_TOTAL=$(dmidecode -t memory | grep 'Size:' | grep -v 'No' | awk '{print $2, $3}')
RAM_TOTAL=$(sudo lshw -C memory | grep -A 4 'System Memory' | grep -v 'cache' | awk '/size:/{print $2}')
RAM_TYPE=$(dmidecode -t memory | grep 'Type:' | grep -v 'Correction' | grep -v 'Unknown' | head -n 1)

# Combine RAM info and free slots
RAM_INFO="$RAM_TOTAL ($RAM_TYPE)"

# WebCam info using inxi -G
WEB_CAM=$(inxi -G | grep -E 'Cam' | awk -F': ' '{print $2}')

# Insert data into the database
mycli -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" <<EOF
INSERT INTO Machine (CPU, RAM, NetworkInterface, GPU, NonNvidiaGPU, SerialNumber, Manufacturer, BatteryHealth, DisplaySize, Storage, Timestamp, UserName, Model, WebCam, Status, LOT_NUMBER)
VALUES ('$CPU', '$RAM_INFO', '$NETWORK_INTERFACE', '$GPU_INFO', '$NON_NVIDIA_GPU_INFO', '$SERIAL_NUMBER', '$MANUFACTURER', '$BATTERY_HEALTH', '$DISPLAY_SIZE', '$HDD_INFO', NOW(),'Weblogics', '$MODEL_NUMBER', '$WEB_CAM', 'Active', '$lot_number');
EOF

if [ $? -eq 0 ]; then
    echo " ------------------------------------------ "
    echo "                 SUCCESS                    "
    echo "Specs Collected and DB Updated in the cloud "
    echo " ------------------------------------------ "
    exit 0
else
    echo " --------------------------------------------- "
    echo "                   ERROR                       "
    echo " Error inserting into DB. Saving to local file "
    echo " --------------------------------------------- "
    collect_system_specs
fi
}

# Main script starts here
# ...

# Example usage:
# Check if an argument is provided (Lot Number)
if [ -n "$1" ]; then
    LOT_NUMBER="$1"
    echo "Received Lot Number: $LOT_NUMBER"
    #welcome_msg
    #list_interfaces
else
    echo "NO ACTIVE LOTS AVAILABLE...QUITTING"
    exit 1
fi

# Run the script
#collect_system_specs
collect_and_send "$LOT_NUMBER"

pkill -f "/home/specvault/specvault-final.sh"
exit 0
