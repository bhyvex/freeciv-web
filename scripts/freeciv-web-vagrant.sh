#!/bin/bash

# Freeciv-web Vagrant Bootstrap Script - play.freeciv.org 
# 2014-02-17 - Andreas Røsdal
#
# Setup script for Freeciv-web to be used on a Vagrant local developer image.
# This script assumes that the source code in git has been checked out from
# https://github.com/freeciv/freeciv-web to /vagrant 

if [ -d "/vagrant/" ]; then
  # script is run to install Freeciv-web under vagrant
  basedir="/vagrant"
  logfile="/vagrant/freeciv-web-vagrant.log"
else
  # script is run to install Freeciv-web on current system without vagrant
  echo "Installing Freeciv-web on current system. Please run this script as root user."
  basedir=$(pwd)"/.."
  logfile="${basedir}/freeciv-web-vagrant.log"
fi


# Redirect copy of output to a log file.
exec > >(tee ${logfile})
exec 2>&1
set -e

echo "================================="
echo "Running Freeciv-web setup script."
echo "================================="

uname -a
echo basedir  $basedir
echo logfile $logfile

# User will need permissions to create a database
mysql_user="root"
mysql_pass="vagrant"

resin_version="4.0.40"
resin_url="http://www.caucho.com/download/resin-${resin_version}.tar.gz"
tornado_url="https://pypi.python.org/packages/source/t/tornado/tornado-3.2.1.tar.gz"

# Based on fresh install of Ubuntu 12.04
dependencies="maven mysql-server-5.5 openjdk-7-jdk libcurl4-openssl-dev nginx libjansson-dev subversion pngcrush python3-pillow libtool automake autoconf autotools-dev language-pack-en python3.4-dev python3-setuptools libglib2.0-dev libbz2-dev imagemagick"

## Setup
mkdir -p ${basedir}
cd ${basedir}

## dependencies
echo "==== Installing Updates and Dependencies ===="
echo "apt-get update"
apt-get -y update
echo "apt-get upgrade"
apt-get -y upgrade
echo "mysql setup..."
sudo debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password password ${mysql_pass}"
sudo debconf-set-selections <<< "mysql-server-5.5 mysql-server/root_password_again password ${mysql_pass}"
echo "apt-get install dependencies"
apt-get -y install ${dependencies}

## build/install resin
echo "==== Fetching/Installing Resin ${resin_version} ===="
wget ${resin_url}
tar xvfz resin-${resin_version}.tar.gz
rm -Rf resin
mv resin-${resin_version} resin

echo "==== Fetching/Installing Tornado Web Server ===="
wget ${tornado_url}
tar xvfz tornado-3.2.1.tar.gz
cd tornado-3.2.1
python3.4 setup.py install


## mysql setup
echo "==== Setting up MySQL ===="
mysqladmin -u ${mysql_user} -p${mysql_pass} create freeciv_web
mysql -u ${mysql_user} -p${mysql_pass} freeciv_web < ${basedir}/freeciv-web/src/main/webapp/meta/private/metaserver.sql

echo "==== Building freeciv ===="
cd ${basedir}/freeciv && ./prepare_freeciv.sh
cd freeciv && make install
cd ${basedir}/freeciv/data/ && cp -rf fcweb /usr/local/share/freeciv

echo "==== Building freeciv-web ===="
sed -e "s/user>root/user>${mysql_user}/" -e "s/password>changeme/password>${mysql_pass}/" ${basedir}/freeciv-web/src/main/webapp/WEB-INF/resin-web.xml.dist > ${basedir}/freeciv-web/src/main/webapp/WEB-INF/resin-web.xml
cd ${basedir}/freeciv-img-extract/ && ./setup_links.sh && ./sync.sh
cd ${basedir}/scripts && ./sync-js-hand.sh
cd ${basedir}/freeciv-web && ./build.sh

echo "=============================="

service nginx stop
rm /etc/nginx/sites-enabled/default
cp ${basedir}/publite2/nginx.conf /etc/nginx/

if [ -d "/vagrant/" ]; then
  echo "Starting Freeciv-web..."
  service nginx start
  cd ${basedir}/scripts/ && sudo -u vagrant ./start-freeciv-web.sh
  echo "Freeciv-web started! Now try http://localhost/ on your host operating system."
else
  echo "Freeciv-web installed. Please start it manually."
fi
