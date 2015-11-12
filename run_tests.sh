#!/usr/bin/env bash
# enable fail detection...
set -e

echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
HOSTIP=$(vagrant ssh-config | awk '/HostName/ {print $2}')

echo -e "\nSETTING up Dokku SSH key.\n"

cat /.ssh/id_rsa.pub | vagrant ssh -c "docker exec -i dokku sshcommand acl-add dokku root"

echo -e "\nCREATING repo\n"

mkdir dockertest
cd dockertest/
git init
git config user.email "engineering@protonet.info"
git config user.name "Protonet Integration Test node.js"

cp ../Dockerfile-sleep Dockerfile
git add .
git commit -a -m "Initial Commit"

echo -e "\nRUNNING git push to ${HOSTIP}\n"

git remote add dokku1 ssh://dokku@${HOSTIP}:8022/app1
git remote add dokku2 ssh://dokku@${HOSTIP}:8022/app2
# destroy in case it's already deployed
ssh -t -p 8022 dokku@${HOSTIP} apps:destroy app1 force || true
ssh -t -p 8022 dokku@${HOSTIP} apps:destroy app2 force || true
# ssh -t -p 8022 dokku@${HOSTIP} trace on
git push dokku1 master
git push dokku2 master

vagrant ssh -c "docker exec -i dokku dokku protonet:ls"
CONTAINER1=$(vagrant ssh -c "docker exec -i dokku dokku protonet:ls" | awk '{if ($1=="app1") print $4;}')

echo "Linking to container '$CONTAINER1'"

vagrant ssh -c "echo $CONTAINER1 > /data/dokku/app2/LINK"
ssh -t -p 8022 dokku@${HOSTIP} ps:rebuild app2

CONTAINER2=$(vagrant ssh -c "docker exec -i dokku dokku protonet:ls" | awk '{if ($1=="app2") print $4;}')
vagrant ssh -c "docker inspect -f '{{.HostConfig.Links}}' $CONTAINER2" | grep -q $CONTAINER1
vagrant ssh -c "docker exec -i $CONTAINER2 ping -q -c1 $CONTAINER1"
