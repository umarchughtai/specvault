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
echo " visit https://specvault.web-logics.com/ to review "
echo " ------------------------------------------------- "
}

# Function to list the connected network interfaces
function list_interfaces() {
    local wlan_interface=$(ip link show | awk -F: '$0 ~ "wlan"{print $2}' | tr -d ' ')
    if [ -n "$wlan_interface" ]; then
        local ip_address=$(ip -4 addr show "$wlan_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        local ssid=$(iwgetid -r)
        echo " ------- WLAN Connected ------- "
        echo " WLAN Interface: $wlan_interface"
        echo " IP Address: $ip_address"
        echo " Connected SSID: $ssid"
        echo " ------------------------------ "
    else
        local eth_interface=$(ip link show | awk -F: '$0 ~ "eth"{print $2}' | tr -d ' ')
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
        echo "                  SUCCESS                      "
        echo "       Internet Connectivity Confirmed         "
        echo "       PROCEEDING WITH SPECS COLLECTION        "
        echo " --------------------------------------------- "
        return 0
    else
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

MYSQL_HOST="162.144.3.115"
MYSQL_USER="weblo1cs_bolt_user"
MYSQL_PASSWORD="MyPassword@123"
MYSQL_DATABASE="weblo1cs_Bolt_laptop_data"

# Collect system specifications
HOSTNAME=$(hostname)
CPU=$(lscpu | grep 'Model name' | awk -F': ' '{print $2}')
#RAM=$(free -h | awk '/^Mem:/ {print $2}')
STORAGE=$(df -h | awk '$NF=="/" {print $2}')
#NETWORK_INTERFACE=$(ip link | awk -F': ' '$0 !~ "lo|vir|wl|^[^0-9]"{print $2; exit}')
NETWORK_INTERFACE=$(inxi -N | awk -F ': ' '/Device/ {gsub(" driver.*", "", $2); gsub("Network ", "", $2); sub("Device-", "", $2); if (i == 1) print "Device-" ++i ": " $2; else print "Device-" ++i ": " $3}')
OS_VERSION=$(lsb_release -d | awk -F'\t' '{print $2}')

# Get GPU information using nvidia-smi (if available)
GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader)

# Check if any GPU (NVIDIA or non-NVIDIA) is available
if [ -z "$GPU_INFO" ]; then
    # No GPU detected
    GPU_INFO="No graphics card available"
fi

# Non-NVIDIA GPU information (if available)
NON_NVIDIA_GPU_INFO=$(lshw -C display | grep -i -A 1 'VGA compatible controller' | grep -v 'NVIDIA' | awk -F': ' '{print $2}')
if [ -z "$NON_NVIDIA_GPU_INFO" ]; then
   NON_NVIDIA_GPU_INFO="NO VGA Compatible Display Adapter Available"
fi

# Get machine serial number
SERIAL_NUMBER=$(cat /sys/class/dmi/id/product_serial)

# Manufacturer or brand of the system
MANUFACTURER=$(dmidecode -s system-manufacturer)

# Battery health (you can customize this based on your system)
BATTERY_HEALTH=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -i 'capacity' | awk '{print $2}')

# Laptop display size (diagonal measurement in inches)
DISPLAY_SIZE=$(lshw -C display | grep -i 'size' | awk -F': ' '{print $2}')

# Hard disk information (including type and available slots)
HDD_INFO=$(lsblk -o NAME,MODEL | grep 'sd' | awk '{print $2}' | head -n 1)
HDD_SLOTS=$(lsblk -o NAME | grep 'sd' | wc -l)

# RAM type and size using free -h
RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
RAM_TYPE=$(dmidecode -t memory | grep 'Type:' | grep -v 'Unknown' | awk '{print $2}' | head -n 1)

# Free RAM slots
FREE_RAM_SLOTS=$(dmidecode -t memory | grep 'Size: No Module Installed' | wc -l)

# Combine RAM info and free slots
RAM_INFO="$RAM_TOTAL ($RAM_TYPE), Free Slots: $FREE_RAM_SLOTS"

# Insert data into the database
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" <<EOF
INSERT INTO Machine (CPU, RAM, NetworkInterface, GPU, NonNvidiaGPU, SerialNumber, Manufacturer, BatteryHealth, DisplaySize, Storage, Timestamp, UserName)
VALUES ('$CPU', '$RAM_INFO', '$NETWORK_INTERFACE', '$GPU_INFO', '$NON_NVIDIA_GPU_INFO', '$SERIAL_NUMBER', '$MANUFACTURER', '$BATTERY_HEALTH', '$DISPLAY_SIZE', '$HDD_INFO ($HDD_SLOTS slots)', NOW(),'Weblogics');
EOF

if [ $? -eq 0 ]; then
    echo "Specs Collected Successfully and DB Updated"
    exit 0
else
    echo "Error inserting data into the DB. Saving Specs to local file"
    collect_system_specs
fi
}

# Main script starts here
# ...

# Example usage:
# Check if an argument is provided (interface name)
if [ -n "$1" ]; then
    chosen_interface="$1"
else
    welcome_msg
    list_interfaces
fi

#dialog --msgbox "$chosen_interface" 10 40
#validate_interface "$chosen_interface"

#if [[ $chosen_interface == wlan* ]]; then
#    configure_wifi
#elif [[ $chosen_interface == ens* ]]; then
#    configure_ethernet "$chosen_interface"
#else
#    show_error "Invalid interface selected."
#fi

# Run the script
#collect_system_specs
collect_and_send
#inxi -N | awk -F ': ' '/Device/ {gsub(" driver.*", "", $2); gsub("Network ", "", $2); sub("Device-", "", $2); if (i == 1) print "Device-" ++i ": " $2; else print "Device-" ++i ": " $3}'
