#!/bin/bash
if [ -f /boot/setup/init.sh ]; then
    sudo /boot/setup/init.sh
    sudo rm /boot/firstboot.sh
fi