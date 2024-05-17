#!/bin/bash

# Function to display the menu
show_menu() {
    echo "1. Set Source Directory"
    echo "2. Set Destination Directory"
    echo "3. Set Backup Frequency (daily, weekly)"
    echo "4. Set Email for Notifications"
    echo "5. Enable/Disable Compression"
    echo "6. Enable/Disable Incremental Backups"
    echo "7. Start Backup"
    echo "8. Exit"
}

# Function to send email notifications
send_email() {
    if [ -n "$email" ]; then
        echo "$1" | msmtp --from=default -t "$email"
    fi
}


# Initialize variables
src_dir=""
dest_dir=""
frequency=""
email=""
enable_compression=false
enable_incremental=false

# Main loop
while true; do
    show_menu
    read -p "Choose an option: " choice

    case $choice in
        1)
            read -p "Enter Source Directory: " src_dir
            ;;
        2)
            read -p "Enter Destination Directory: " dest_dir
            ;;
        3)
            read -p "Enter Backup Frequency (daily, weekly): " frequency
            ;;
        4)
            read -p "Enter Email for Notifications: " email
            ;;
        5)
            enable_compression=$(! $enable_compression)
            echo "Compression is now $enable_compression"
            ;;
        6)
            enable_incremental=$(! $enable_incremental)
            echo "Incremental backup is now $enable_incremental"
            ;;
        7)
            if [ -z "$src_dir" ] || [ -z "$dest_dir" ] || [ -z "$frequency" ]; then
                echo "Source, destination directories, and frequency must be set!"
            else
                # Create destination directory if it doesn't exist
                mkdir -p "$dest_dir"

                # Define the backup filename
                timestamp=$(date +%Y%m%d%H%M%S)
                backup_file="$dest_dir/backup_$timestamp.tar"

                # Create the backup
                if [ "$enable_incremental" = true ]; then
                    # Incremental backup
                    tar --listed-incremental="$dest_dir/backup.snar" -cf "$backup_file" "$src_dir"
                else
                    # Full backup
                    tar -cf "$backup_file" "$src_dir"
                fi

                # Compress the backup file if enabled
                if [ "$enable_compression" = true ]; then
                    gzip "$backup_file"
                    backup_file="$backup_file.gz"
                fi

                # Check if the backup was successful
                if [ $? -eq 0 ]; then
                    echo "Backup completed successfully."
                    send_email "Backup completed successfully."
                else
                    echo "Backup failed."
                    send_email "Backup failed."
                    exit 1
                fi

                # Schedule the backup using cron
                cron_command="0 0 * * * $0 -s $src_dir -d $dest_dir -f $frequency ${email:+-e $email} ${enable_compression:+-c} ${enable_incremental:+-i}"
                (crontab -l 2>/dev/null; echo "$cron_command") | crontab -
                echo "Backup scheduled with cron."
            fi
            ;;
        8)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option!"
            ;;
    esac
done
