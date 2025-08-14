#!/bin/bash

# Update the package list
sudo apt-get update

mkdir my_test

# Download Harbor installer
wget https://github.com/goharbor/harbor/releases/download/v2.5.0/harbor-online-installer-v2.5.0.tgz

# Extract the installer
tar xvf harbor-online-installer-v2.5.0.tgz


