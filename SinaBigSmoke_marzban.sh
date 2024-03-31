#!/bin/bash

# Define message to be sent along with the file
MESSAGE=""

# Get Discord webhook URL from user
read -p "Please enter the Discord webhook URL: " WEBHOOK_URL

# Get message from user
read -p "Please enter the message: " MESSAGE

# Get cron job from user
read -p "Please enter the cron job schedule (e.g., '0 0 * * *' for daily at midnight): " CRON_JOB

# Install zip package
sudo apt update
sudo apt install zip -y

# Remove existing backup zip file
sudo rm -rf /root/SinaBigSmoke-m.zip

# Define path to the zip file
FILE_PATH="/root/SinaBigSmoke-m.zip"

# Display current system time
echo "Current system time:"
date

# Display chosen cron job
echo "Chosen cron job schedule:"
echo "$CRON_JOB"

# Get and display cron jobs
echo "Cron jobs:"
sudo crontab -l

# Add the cron job
echo "$CRON_JOB /bin/bash /root/SinaBigSmoke_marzban.sh" | sudo crontab -

# Define message for Marzban backup
if dir=$(find /opt /root -type d -iname "marzban" -print -quit); then
    echo "The folder exists at $dir"
else
    echo "The folder does not exist."
    exit 1
fi

if [ -d "/var/lib/marzban/mysql" ]; then

    sed -i -e 's/\s*=\s*/=/' -e 's/\s*:\s*/:/' -e 's/^\s*//' /opt/marzban/.env

    docker exec marzban-mysql-1 bash -c "mkdir -p /var/lib/mysql/db-backup"
    source /opt/marzban/.env

    cat > "/var/lib/marzban/mysql/SinaBigSmoke_marzban.sh" <<EOL
#!/bin/bash

USER="root"
PASSWORD="$MYSQL_ROOT_PASSWORD"

databases=\$(mysql -h 127.0.0.1 --user=\$USER --password=\$PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

for db in \$databases; do
    if [[ "\$db" != "information_schema" ]] && [[ "\$db" != "mysql" ]] && [[ "\$db" != "performance_schema" ]] && [[ "\$db" != "sys" ]] ; then
        echo "Dumping database: \$db"
        mysqldump -h 127.0.0.1 --force --opt --user=\$USER --password=\$PASSWORD --databases \$db > /var/lib/mysql/db-backup/\$db.sql
    fi
done
EOL
    chmod +x /var/lib/marzban/mysql/SinaBigSmoke_marzban.sh

    ZIP=$(cat <<EOF
docker exec marzban-mysql-1 bash -c "/var/lib/mysql/SinaBigSmoke_marzban.sh"
zip -r $FILE_PATH /opt/marzban/* /var/lib/marzban/* /opt/marzban/.env -x /var/lib/marzban/mysql/\*
zip -r $FILE_PATH /var/lib/marzban/mysql/db-backup/*
rm -rf /var/lib/marzban/mysql/db-backup/*
EOF
    )
else
    ZIP="zip -r $FILE_PATH ${dir}/* /var/lib/marzban/* /opt/marzban/.env"
fi

# Send the Marzban backup file using curl
curl -X POST -H "Content-Type: multipart/form-data" -F "content=$MESSAGE" -F "file=@$FILE_PATH" $WEBHOOK_URL

# Display success message
echo "Backup marzban file sent successfully to Discord webhook. Coded By SinaBigSmoke <3"