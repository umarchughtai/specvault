#!/bin/bash

# Wait for network to be up
while ! ping -c 1 google.com &> /dev/null; do
    echo "Waiting for network..."
    sleep 1
done

echo "Network is up and running. Starting the service..."

MYSQL_HOST="182.184.69.131"
MYSQL_USER="boltc"
MYSQL_PASSWORD="Abeeha@7864"
MYSQL_DATABASE="web_logics_db"

# Check if mysql command is available

QUERY="SELECT LOT_NUMBER FROM LOTS WHERE Status='Active';"

LOT_NUMBER=$(mycli -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -D "$MYSQL_DATABASE" -e "$QUERY" | awk 'NR>1 {print $1}')

#echo "$LOT_NUMBER"

if [ -n "$LOT_NUMBER" ]; then
  echo "Collecting Information Under Active Lot Number: $LOT_NUMBER"
  /home/boltc/testfolder/collect_specs_final.sh "$LOT_NUMBER"
  echo "UPDATING LOT INFORMATION"
else
  echo " ----------- ERROR --------------"
  echo "   No active lot in the system   "
  echo "  Please check the cloud portal  "
  echo " Create an active LOT to proceed "
  echo "           QUITTING              "
  echo " --------------------------------"
  exit 1
fi

update_number_of_machines() {
  local lot_number="$1"
  local update_query="UPDATE LOTS SET RECORDED_SYSTEMS = RECORDED_SYSTEMS + 1 WHERE LOT_NUMBER='$lot_number';"
  mycli -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -D "$MYSQL_DATABASE" -e "$update_query"
  
  local exit_status=$?

  # Check if the query was successful
  if [ $exit_status -eq 0 ]; then
    echo "Update successful for LOT: $lot_number."
  else
    echo "Error updating LOT: $lot_number. Exit status: $exit_status."
  fi
}

update_number_of_machines "$LOT_NUMBER"
#poweroff
