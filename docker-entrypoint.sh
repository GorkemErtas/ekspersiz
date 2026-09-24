#!/bin/sh
set -e

mkdir -p /data/uploads
chown -R ekspersiz:ekspersiz /data/uploads

exec runuser -u ekspersiz -- java -jar /app/app.jar