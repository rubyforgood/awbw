#!/bin/sh -x

############ ----- NEW_PRODUCTION (awbw-new-production.zgdev1.com) ------ ##########

ssh awbw.new_production <<EOF

cd /home/devteam/public_html/awbw/
mysqldump -h localhost -u root --password=$MYSQL_AWBW_PASS awbw_production > awbw_new_production.sql
EOF

DATE=`date +%Y-%m-%d`
scp awbw.new_production:/home/devteam/public_html/awbw/awbw_new_production.sql ../backups/awbw_new_production-$DATE.sql

############ ----- PRODUCTION (dashboard.awbw.org) ------ ##########

ssh devteam@dashboard.awbw.org <<EOF

cd /home/devteam/public_html/awbw/
mysqldump -h localhost -u root --password=$MYSQL_AWBW_PASS awbw_production > awbw_production.sql
EOF

DATE=`date +%Y-%m-%d`
scp devteam@dashboard.awbw.org:/home/devteam/public_html/awbw/awbw_production.sql ../backups/awbw_production-$DATE.sql

