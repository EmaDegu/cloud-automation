
#!/bin/bash
set -e
yum update -y
amazon-linux-extras install nginx1 -y
echo "ok" > /usr/share/nginx/html/health
systemctl enable nginx
systemctl start nginx
