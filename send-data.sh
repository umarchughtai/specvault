#!/bin/bash

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
    echo "System specifications inserted successfully!"
else
    echo "Error inserting data into the database."
fi
