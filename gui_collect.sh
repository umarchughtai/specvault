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
collect_system_specs
