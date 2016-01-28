#! /bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script can only be run as root!" 1>&2
  exit 1
fi

echo 'Step 1 of 5'
echo '  Starting inadyn to connect to the domain name'
inadyn -u imgod22222@aim.com -a imgod2222.mooo.com,VGo4YmJVRXhKT29BQUw1QnRGMDozNTU2OTk3 &

echo 'Step 2 of 5'
echo '  Starting up the usbip daemon'
sudo usbipd -D

echo 'Step 3 of 5'
echo '  Determining which Vendor/Device ID belongs to the X360 controller'
lsusb | grep Xbox360 | cut -f6 -d' '
VENDOR_DEVICE_ID=`lsusb | grep Xbox360 | cut -f6 -d' '`

echo 'Step 4 of 5'
echo '  Determining busID of the Xbox360 controller'
sudo usbip_bind_driver --list | grep $VENDOR_DEVICE_ID | cut -f4 -d' '
BUS_ID=`sudo usbip_bind_driver --list | grep $VENDOR_DEVICE_ID | cut -f4 -d' '`

echo 'Step 5 of 5'
echo '  Attach Xbox360 controller at busID  $BUS_ID  to USBIP'
sudo usbip_bind_driver --usbip $BUS_ID
echo 'USBIP bound complete!'
