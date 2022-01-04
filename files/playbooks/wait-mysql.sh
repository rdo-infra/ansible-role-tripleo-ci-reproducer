#!/bin/bash
set -x
TIMEOUT=30
COUNT=$TIMEOUT
echo "Waiting for mysql to become available...."
while : ; do
    timeout 15 bash -c "cat </dev/null >/dev/tcp/mysql/3306"
    if [ $? -eq 0 ]; then
        break
    fi
    COUNT=$((COUNT-1))
    sleep 5
    if [ $COUNT -le 0 ]; then
        echo "Mysql is not available on 3306 after $TIMEOUT seconds"
        exit 1
    fi
done
echo "MySQL is available"
