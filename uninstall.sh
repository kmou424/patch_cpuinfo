#!/usr/bin/bash

source dkms.conf
sudo dkms uninstall ${PACKAGE_NAME}/${PACKAGE_VERSION}
sudo rm -r /usr/src/${PACKAGE_NAME}-${PACKAGE_VERSION}
