#!/bin/bash

# Function to display an error message and exit
function show_error() {
    dialog --msgbox "$1" 20 60
    exit 1
}

# Function to list available network interfaces
function list_interfaces() {
    local interfaces=($(ip link show | awk -F: '$0 !~ "lo|vir|^[^0-9]"{print $2}'))
    local options=()
    for iface in "${interfaces[@]}"; do
        options+=("$iface" "")
    done
    chosen_interface=$(dialog --ascii-lines --title "Network Interface" --menu "Please select a network interface:" 20 60 "${#interfaces[@]}" "${options[@]}" 2>&1 >/dev/tty)
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
    ip_address=$(nmcli -g IP4.ADDRESS dev show | grep -oP '(\d{1,3}\.){3}\d{1,3}')

    # Display IP address
    dialog --ascii-lines --title "Obtaining IP" --msgbox "IP Address obtained: $ip_address" 20 60
    ping_output=$(ping -c 4 8.8.8.8)
    dialog --ascii-lines --title "Checking Internet Connectivity" --msgbox "Ping output:\n\n$ping_output" 20 60
    #ping -c 4 8.8.8.8
    if [ $? -eq 0 ]; then
        dialog --ascii-lines --title "Success" --msgbox "Internet connectivity confirmed." 20 60
        return 0
    else
        dialog --ascii-lines --title "Error" --msgbox "Failed to connect to the internet. Please choose the correct interface or ensure internet connectivity" 20 60
        return 1
    fi

}

# Function to collect system specs
function collect_system_specs() {
    dialog --ascii-lines --title "Collect Hardware Specs" --yesno "Allow to collect system specs?" 20 60
    if [ $? -eq 0 ]; then
        #dialog --ascii-lines --title "Collection in Progress" --msgbox "Collecting Specs for the System..." 20 60
        lshw -short >> hardware.txt
        lscpu >> hardware.txt
        inxi -Fxz >> specs.txt
        dialog --ascii-lines --title "Finalization" --msgbox "Specs Collected and Closing the Script" 20 60
        #dialog --msgbox  "Press OK to exit the program: " 10 40
        exit 0
    else
        echo "Specs collection canceled."
    fi
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
NETWORK_INTERFACE=$(ip link | awk -F': ' '$0 !~ "lo|vir|wl|^[^0-9]"{print $2; exit}')
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
BATTERY_HEALTH=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -i 'state' | awk '{print $2}')

# Laptop display size (diagonal measurement in inches)
DISPLAY_SIZE=$(lshw -C display | grep -i 'size' | awk -F': ' '{print $2}')

# Hard disk information (including type and available slots)
HDD_INFO=$(lsblk -o NAME,SIZE,TYPE | grep 'sd' | awk '{print $1, $2, $3}')
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
VALUES ('$CPU_MODEL', '$RAM_INFO', '$NETWORK_INTERFACE', '$GPU_INFO', '$NON_NVIDIA_GPU_INFO', '$SERIAL_NUMBER', '$MANUFACTURER', '$BATTERY_HEALTH', '$DISPLAY_SIZE', '$HDD_INFO ($HDD_SLOTS slots)', NOW(),'Weblogics');
EOF

if [ $? -eq 0 ]; then
    dialog --ascii-lines --title "Finalization" --msgbox "Specs Collected Successfully and DB Updated" 20 60
    exit 0
else
    dialog --ascii-lines --title "Finalization" --msgbox "Error inserting data into the DB" 20 60
fi
}

# Main script starts here
# ...

# Example usage:
# Check if an argument is provided (interface name)
if [ -n "$1" ]; then
    chosen_interface="$1"
else
    dialog --ascii-lines --title "Welcome to Bolt ASC" --msgbox "Bolt ASC is an automated specfication collection system that will read the hardware specs. It will automatically upload the collected data to a cloud platform to which you have subscribed. We will need internet connectivity for pushing the data. Let's Start "  10 60
    list_interfaces
fi

#dialog --msgbox "$chosen_interface" 10 40
validate_interface "$chosen_interface"

if [[ $chosen_interface == wlan* ]]; then
    configure_wifi
elif [[ $chosen_interface == ens* ]]; then
    configure_ethernet "$chosen_interface"
else
    show_error "Invalid interface selected."
fi

# Run the script
#collect_system_specs
collect_and_send