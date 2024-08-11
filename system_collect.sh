#!/bin/bash

# Function to run the script in a new terminal window
function run_in_new_terminal() {
    local script="$1"
    sudo openvt -s -w -- "$script"
}


function list_interfaces() {
    echo "Available network interfaces:"
    ip link show | awk -F: '$0 !~ "lo|vir|^[^0-9]"{print $2}'
}

function configure_ethernet() {
    sudo dhclient "$1"
    check_connectivity
}

function configure_wifi() {
    echo "Scanning for available Wi-Fi networks..."
    nmcli dev wifi list

    read -p "Enter the SSID of the Wi-Fi network: " ssid
    read -sp "Enter the password for the Wi-Fi network: " password
    echo

    sudo nmcli device wifi connect "$ssid" password "$password"
    check_connectivity
}

function check_connectivity() {
    ip_address=$(nmcli -g IP4.ADDRESS dev show | grep -oP '(\d{1,3}\.){3}\d{1,3}')
    echo "IP Address obtained: $ip_address"
    ping -c 4 8.8.8.8
    if [ $? -eq 0 ]; then
        echo "Internet connectivity confirmed."
        return 0
    else
        echo "Failed to connect to the internet."
        return 1
    fi
}

function collect_system_specs() {
    echo "Collecting Specs for the System..."
    lshw -short > hardware.txt
    lscpu >> hardware.txt
    echo "Specs Collected and Closing the Script"
    read -p "Press any key to exit the  Program: " close_input
    exit 0
}

# Check if an argument is provided (interface name)
if [ -n "$1" ]; then
    chosen_interface="$1"
else
    list_interfaces
    read -p "Enter the network interface name for internet access: " chosen_interface
fi

if [[ $chosen_interface == wlan* ]]; then
    if ! configure_wifi; then
        echo "Wi-Fi configuration failed."
        exit 1
    fi
else
    if ! configure_ethernet "$chosen_interface"; then
        echo "Ethernet configuration failed."
        exit 1
    fi
fi

# Run the script in a new terminal window
collect_system_specs
#run_in_new_terminal "/home/boltc/system_collect.sh"

# Close the terminal window (kill the openvt session)
pkill -f "/home/boltc/system_collect.sh"
exit 0
