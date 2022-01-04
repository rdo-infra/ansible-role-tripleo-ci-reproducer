#!/bin/bash
set -x
TIMEOUT=600
COUNT=$TIMEOUT
echo "Waiting for gerrit to become available...."
while : ; do
    timeout 10 bash -c "cat </dev/null >/dev/tcp/gerrit/29418"
    if [ $? -eq 0 ]; then
        break
    fi
    COUNT=$((COUNT-1))
    sleep 1
    if [ $COUNT -le 0 ]; then
        echo "Gerrit is not available on 29318 after $TIMEOUT seconds"
        exit 1
    fi
done

echo "Waiting for gerritconfig to be finished...."
COUNT=$TIMEOUT
while : ; do
    CODE=$(curl -s -u admin:secret -o /dev/null --write-out "%{http_code}" http://gerrit:8080/a/accounts/zuul/sshkeys)
    if [ $CODE -eq 200 ]; then
        break
    fi
    COUNT=$((COUNT-1))
    sleep 1
    if [ $COUNT -le 0 ]; then
        echo "Zuul is not available after $TIMEOUT seconds"
        exit 1
    fi
done
