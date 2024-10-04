#!/bin/bash

# Check if Wi-Fi is connected
if nmcli -t -f WIFI g | grep -q "enabled" && nmcli -t -f IP4.ADDRESS dev show | grep -q "IP4.ADDRESS"; then
    echo "Wi-Fi is already connected. Running the main script..."
    /path/to/your/main_script.sh
else
    # Start nmtui to connect to Wi-Fi
    echo "Please connect to a Wi-Fi network using nmtui."
    sudo nmtui-connect

    # Wait for the user to connect to Wi-Fi
    while ! nmcli -t -f WIFI g | grep -q "enabled"; do
        sleep 1
    done

    # Wait for an IP address to be assigned
    while ! nmcli -t -f IP4.ADDRESS dev show | grep -q "IP4.ADDRESS"; do
        echo "Waiting for IP address..."
        sleep 1
    done

    echo "Wi-Fi connected and IP address obtained. Running the main script..."
    /path/to/your/main_script.sh
fi
