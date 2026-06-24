#!/bin/sh -e
#
#  Copyright 2021, Roger Brown
#
#  This file is part of rhubarb pi.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# $Id: package.sh 39 2021-04-24 12:52:41Z rhubarb-geek-nz $
#

svnVer()
{
	while read A B C D
	do
		echo "$C"
	done << EOF
$Id: package.sh 39 2021-04-24 12:52:41Z rhubarb-geek-nz $
EOF
}

cleanup()
{
	rm -rf root meta
}

getSize()
{
	du -sk root | while read A B
	do
		echo $A
	done
}

cleanup

trap cleanup 0

VERSION=`svnVer`
VERSION="1.0.$VERSION"
PKGNAME=rhubarb-pi-fan
FANPIN=18

mkdir -p root/DEBIAN

cat > root/DEBIAN/postinst <<EOF
#!/bin/sh -e
if test ! -h /etc/systemd/system/rhubarb-pi-fan.service
then
	ln -s /opt/RHBpifan/etc/rhubarb-pi-fan.service /etc/systemd/system/rhubarb-pi-fan.service
fi
if test ! -h /etc/systemd/system/rhubarb-pi-fan.timer
then
	ln -s /opt/RHBpifan/etc/rhubarb-pi-fan.timer /etc/systemd/system/rhubarb-pi-fan.timer
fi
if test ! -h /etc/systemd/system/timers.target.wants/rhubarb-pi-fan.timer
then
	ln -s /opt/RHBpifan/etc/rhubarb-pi-fan.timer /etc/systemd/system/timers.target.wants/rhubarb-pi-fan.timer
fi
EOF

cat > root/DEBIAN/postrm <<EOF
#!/bin/sh -e
rm -rf /etc/systemd/system/rhubarb-pi-fan.service /etc/systemd/system/timers.target.wants/rhubarb-pi-fan.timer /etc/systemd/system/rhubarb-pi-fan.timer
EOF

chmod +x root/DEBIAN/post*

(
	set -e
	cd root
	mkdir -p opt/RHBpifan/etc opt/RHBpifan/bin

	cat >  opt/RHBpifan/bin/rhubarb-pi-fan.sh << EOF
#!/bin/sh -e
gpio -g mode $FANPIN out
TEMP=\$(cat /sys/class/thermal/thermal_zone0/temp)
if test "\$TEMP" -gt 70000
then
	gpio -g write $FANPIN 1
else
	if test "\$TEMP" -lt 65000
	then
		gpio -g write $FANPIN 0
	fi
fi
EOF

	cat >  opt/RHBpifan/etc/rhubarb-pi-fan.service << 'EOF'
[Unit]
Description=Monitors the temperature
Wants=rhubarb-pi-fan.timer

[Service]
Type=oneshot
ExecStart=/opt/RHBpifan/bin/rhubarb-pi-fan.sh

[Install]
WantedBy=multi-user.target
EOF

	cat >  opt/RHBpifan/etc/rhubarb-pi-fan.timer << 'EOF'
[Unit]
Description=Monitors the temperature
Requires=rhubarb-pi-fan.service

[Timer]
Unit=rhubarb-pi-fan.service
OnCalendar=*-*-* *:*:00

[Install]
WantedBy=timers.target
EOF
	
	chmod +x opt/RHBpifan/bin/rhubarb-pi-fan.sh
)

SIZE=`getSize`

cat > root/DEBIAN/control <<EOF
Package: $PKGNAME
Version: $VERSION
Architecture: all
Installed-Size: $SIZE
Maintainer: rhubarb-geek-nz@users.sourceforge.net
Section: electronics
Priority: extra
Depends: wiringpi (>= 2.52)
Vcs-Svn: https://svn.code.sf.net/p/rhubarb-pi/code/trunk/pkg/rhubarb-pi-fan
Description: Fan Control
 Fan Control on GPIO $FANPIN
 .
EOF

if dpkg-deb --root-owner-group --build root "$PKGNAME"_"$VERSION"_all.deb
then
	ls -ld "$PKGNAME"_"$VERSION"_all.deb
	dpkg-deb -c  "$PKGNAME"_"$VERSION"_all.deb
fi

cleanup

mkdir -p root/usr/local/libexec meta

cat > root/usr/local/libexec/rhubarb-pi-fan << EOF
#!/bin/sh -e

sysctl -n hw.sensors.bcmtmon0.temp0 | sed y/./\ / | while read A B
do 
	if test "\$A" -gt 70
	then
		/usr/sbin/gpioctl -q gpio0 fan on
	else
		if test "\$A" -lt 65
		then
			/usr/sbin/gpioctl -q gpio0 fan off
		fi
	fi
done
EOF

chmod +x  root/usr/local/libexec/rhubarb-pi-fan

ADD=/root/rhubarb-pi-fan.pkg.add
DEL=/root/rhubarb-pi-fan.pkg.del
RCSL=/etc/rc.securelevel
GPIOSET="/usr/sbin/gpioctl gpio0 $FANPIN set out fan"

cat > meta/CONTENTS <<EOF
usr/local/libexec/rhubarb-pi-fan
@exec-add crontab -l > $ADD && echo "*\t*\t*\t*\t*\t/usr/local/libexec/rhubarb-pi-fan" >> $ADD && crontab $ADD && rm $ADD
@exec-add if test ! -f $RCSL; then echo "#!/bin/sh" > $RCSL; chmod u+x $RCSL; fi
@exec-add if grep "$GPIOSET" $RCSL; then : ; else echo "$GPIOSET" >> $RCSL; fi
@unexec-delete crontab -l | grep -v /usr/local/libexec/rhubarb-pi-fan > $DEL && crontab $DEL && rm $DEL
@unexec-delete if grep "$GPIOSET" $RCSL; then cp $RCSL $DEL && grep -v "$GPIOSET" < $RCSL > $DEL && mv $DEL $RCSL; fi
@unexec-delete if grep "#!/bin/sh" $RCSL && test 1 -eq \$(wc -l < $RCSL); then rm $RCSL; fi 
EOF

echo Fan control for Raspberry Pi 4 Case Fan on OpenBSD > meta/DESC

if pkg_create -A "*" \
	-d meta/DESC \
	-D "COMMENT=Fan control" \
	-D MAINTAINER=rhubarb-geek-nz@users.sourceforge.net \
	-D FULLPKGPATH=misc/rhubarb-pi-fan \
	-D FTP=yes \
	-f meta/CONTENTS \
	-B $(pwd)/root \
	-p / \
	$PKGNAME-$VERSION.tgz
then
	ls -ld $PKGNAME-$VERSION.tgz
fi
