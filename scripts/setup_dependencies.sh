#!/bin/bash
set -ex

echo "Installing node 22"
. "$HOME/.nvm/nvm.sh"
nvm install 22
echo "Installing Rails dependencies"
bundler install

# Run DB on docker
docker run --name awbw_mysql -e MYSQL_ALLOW_EMPTY_PASSWORD=true -e MYSQL_DATABASE=awbw_development -p 3306:3306 -d mysql:latest -a
# Wait for DB to be available
echo "Waiting for database to be ready..."
sleep 15 # Let's wait a bit for the DB to be ready 
# Migrate schemas
rake db:migrate
# Set up users
rake db:seed