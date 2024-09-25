#!/bin/bash

# ---------- Find Display Size -----------------------------------
# Extract the width and height in millimeters
WIDTH=$(hwinfo --monitor | grep -i 'Size' | awk -F'[x]' '{print $2}' | tr -d '[:space:]')
HEIGHT=$(hwinfo --monitor | grep -i 'Size' | awk -F'[x]' '{print $3}' | tr -d '[:space:]')

# Convert width and height to numeric values
WIDTH=$(echo "$WIDTH" | awk '{print int($1)}')
HEIGHT=$(echo "$HEIGHT" | awk '{print int($1)}')

# Ensure WIDTH and HEIGHT are numbers
if ! [[ "$WIDTH" =~ ^[0-9]+$ ]] || ! [[ "$HEIGHT" =~ ^[0-9]+$ ]]; then
    echo "Error: Width and Height must be numeric values."
    exit 1
fi

# Calculate the diagonal size in millimeters
DIAGONAL_MM=$(echo "scale=2; sqrt($WIDTH^2 + $HEIGHT^2)" | bc)

# Convert the diagonal size from millimeters to inches (1 inch = 25.4 mm)
DIAGONAL_INCHES=$(echo "scale=2; $DIAGONAL_MM / 25.4" | bc)

# Extract the resolution
RESOLUTION=$(hwinfo --monitor | grep -i 'Resolution' | awk -F': ' '{print $2}' | tr -d '[:space:]')

# Combine the diagonal size and resolution into the DISPLAY_SIZE variable
DISPLAY_SIZE="${DIAGONAL_INCHES} inches, Resolution: ${RESOLUTION}"

# Output the display size
echo "Display Size: $DISPLAY_SIZE"
#----------------------------------------------------------------