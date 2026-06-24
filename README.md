# rhubarb-geek-nz/rhubarb-pi-fan
Simple scripts to manage fan on RPI4 where other alternatives don't exist

## Ubuntu
This implements a systemd timer service to monitor the temperature and control the fan.
```
/opt/RHBpifan/bin/rhubarb-pi-fan.sh
/opt/RHBpifan/etc/rhubarb-pi-fan.service
/opt/RHBpifan/etc/rhubarb-pi-fan.timer
```

## OpenBSD
This implements a crobjob to monitor the temperature and control the fan
The GPIO device is set up in /etc/rc.securelevel and named as "fan"
```
# cat /etc/rc.securelevel 
#!/bin/sh
/usr/sbin/gpioctl gpio0 18 set out fan
```
Pin 18 is chosen as 14 is already allocated for the console TTY.
It adds a cronjob
```
*	*	*	*	*	/usr/local/libexec/rhubarb-pi-fan
```
