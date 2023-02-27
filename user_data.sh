#!/bin/bash
sudo apt update
sudo apt install -y nginx
sudo apt install -y python3-pip
sudo apt install -y build-essential libssl-dev libffi-dev python3-dev python3-venv

myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`

sudo chown -R $USER:$USER /var/www
cat <<EOF >> /var/www/html/index.nginx-debian.html
<h2><font color=green>$myip </font></h2>
EOF

sudo nginx -s reload
