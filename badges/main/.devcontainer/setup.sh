#!/bin/bash
set -ex

# Start database
service mariadb start

echo "Setting up Mise"
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >>~/.bashrc
source ~/.bashrc
mise trust -a
mise settings add idiomatic_version_file_enable_tools ruby

# Allow root to connect without password
mysql -u root -e "
  ALTER USER 'root'@'localhost' IDENTIFIED BY '';
  FLUSH PRIVILEGES;
"

# app setup
mise i
mise run setup
echo "Start the server by running mise server"
