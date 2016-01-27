#! /bin/bsh
echo 'This is a script to connect to the USBIP host which has the connected X360 controller. It requires the remote (non-robot) computer to be ON, and having successfully ran its host.sh setup file.'
USBIP_HOST_IP=`host imgod22222.mooo.com | cut -f4 -d' '` #returns the IP address for the USBIP host
usbip -l $USBIP_HOST_IP
echo 'Operator should visually confirm that 4-2 is the 360 controller'
usbip -a $USBIP_HOST_IP 4-2 #4-2 is chosen after having done usbip -l $USBIP_HOST_IP
echo 'The file has successfully completed'
