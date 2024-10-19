#!/usr/bin/bash

source dkms.conf
sudo mkdir /usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}
sudo cp * /usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}
sudo dkms install ${PACKAGE_NAME}/${PACKAGE_VERSION}
