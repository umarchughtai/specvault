#!/bin/bash

# Function to check network connectivity
check_network() {
    #wget -q --spider http://google.com
    while ! ping -c 1 google.com &> /dev/null; do
        echo "Waiting for network..."
        sleep 1
    done
    echo "Network is up and running. Starting the service..."
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
    return 0
    #if [ $? -eq 0 ]; then
    #    echo "Network is available."
    #    return 0
    #else
    #    echo "Network is not available."
    #    return 1
    #fi
}

# Function to download a script from GitHub
download_script() {
    local url=$1
    local dest=$2
    wget -O "$dest" "$url"
    if [ $? -eq 0 ]; then
        echo "Script downloaded successfully: $dest"
        return 0
    else
        echo "Failed to download script: $dest"
        return 1
    fi
}

# Function to convert script to Unix format
convert_to_unix() {
    local file=$1
    dos2unix "$file"
    if [ $? -eq 0 ]; then
        echo "Converted to Unix format: $file"
        return 0
    else
        echo "Failed to convert to Unix format: $file"
        return 1
    fi
}

# Function to add execution permissions
add_permissions() {
    local file=$1
    chmod +x "$file"
    if [ $? -eq 0 ]; then
        echo "Execution permissions added: $file"
        return 0
    else
        echo "Failed to add execution permissions: $file"
        return 1
    fi
}

# Function to execute the script
execute_script() {
    local file=$1
    "$file"
    if [ $? -eq 0 ]; then
        echo "Script executed successfully: $file"
        return 0
    else
        echo "Failed to execute script: $file"
        return 1
    fi
}

# Function to remove the script
remove_script() {
    local file=$1
    rm "$file"
    if [ $? -eq 0 ]; then
        echo "Script removed successfully: $file"
        return 0
    else
        echo "Failed to remove script: $file"
        return 1
    fi
}

# Main script logic
main() {
    local script_url1="https://raw.githubusercontent.com/umarchughtai/specvault/main/connect-to-sql.sh"
    local script_url2="https://raw.githubusercontent.com/umarchughtai/specvault/main/collect_specs_final.sh"
    local script_path1="/etc/connect_to-sql.sh"
    local script_path2="/etc/collect_specs_final.sh"

    check_network
    if [ $? -eq 0 ]; then
        echo "Downloading SpecVault .... "
        download_script "$script_url1" "$script_path1" &
        download_script "$script_url2" "$script_path2" &
        wait

        if [ $? -eq 0 ]; then
            echo "Converting files ... "
            convert_to_unix "$script_path1"
            convert_to_unix "$script_path2"
            if [ $? -eq 0 ]; then
                echo "Adding permissions ... "
                add_permissions "$script_path1"
                add_permissions "$script_path2"
                if [ $? -eq 0 ]; then
                    echo "Executing SpecVault ... "
                    execute_script "$script_path1"
                    #execute_script "$script_path2"
                    if [ $? -eq 0 ]; then
                        remove_script "$script_path1"
                        remove_script "$script_path2"
                    fi
                fi
            fi
        fi
    fi
}

# Execute the main function
main
