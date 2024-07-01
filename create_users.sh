#!/bin/bash

# Check if the file is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi

USER_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure the log and password files exist
sudo touch $LOG_FILE
sudo mkdir -p /var/secure
sudo touch $PASSWORD_FILE

# Ensure only the file owner can read the password file
sudo chmod 600 $PASSWORD_FILE

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a $LOG_FILE
}

# Function to generate a random password
generate_password() {
    echo "$(openssl rand -base64 12)"
}

# Read the user file line by line
while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove whitespace
    line=$(echo $line | tr -d ' ')

    # Parse username and groups
    username=$(echo $line | cut -d';' -f1)
    groups=$(echo $line | cut -d';' -f2)

    # Create the user and their personal group
    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping."
    else
        sudo useradd -m -s /bin/bash $username
        if [ $? -eq 0 ]; then
            log_message "Created user $username."
        else
            log_message "Failed to create user $username."
            continue
        fi
    fi

    # Create and add to additional groups
    IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
        if ! getent group $group > /dev/null; then
            sudo groupadd $group
            log_message "Created group $group."
        fi
        sudo usermod -aG $group $username
        if [ $? -eq 0 ]; then
            log_message "Added user $username to group $group."
        else
            log_message "Failed to add user $username to group $group."
        fi
    done

    # Set up home directory permissions
    sudo chmod 700 /home/$username
    sudo chown $username:$username /home/$username
    log_message "Set permissions for home directory of user $username."

    # Generate and store password
    password=$(generate_password)
    echo "$username:$password" | sudo chpasswd
    if [ $? -eq 0 ]; then
        log_message "Set password for user $username."
        echo "$username,$password" | sudo tee -a $PASSWORD_FILE
    else
        log_message "Failed to set password for user $username."
    fi

done < $USER_FILE

log_message "User creation script completed."
