#!/bin/bash

MYSQL_HOST="162.144.3.115"
MYSQL_USER="weblo1cs_bolt_user"
MYSQL_PASSWORD="MyPassword@123"
MYSQL_DATABASE="weblo1cs_Bolt_laptop_data"

# Check if mysql command is available
if ! command -v mysql &> /dev/null; then
  echo "mysql command not found. Please install it."
  exit 1
fi

# Attempt to connect and execute query
if mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$query" "$MYSQL_DATABASE" &> /dev/null; then
  echo "Connection to MySQL database successful!"
else
  echo "Error connecting to MySQL database or executing query"
  exit 1
fi

