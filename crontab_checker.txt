#!/bin/bash

for user in $(cut -d ":" -f 1 /etc/passwd); do
    crontab_content=$(sudo -u $user crontab -l 2>/dev/null | grep -v "^#")
    
    if [ -n "$crontab_content" ]; then
        echo "Username: $user"
        echo "Crontab:"
        echo "$crontab_content"
        echo "------------------------"
    fi
done
