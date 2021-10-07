#!/bin/sh

# write commit hash
if [ "$COMMIT_HASH" ]; then
	echo "$COMMIT_HASH" >/etc/release
fi

# disable filesystem checking (no e2fsprogs)
sed -i 's/1$/0/' /etc/fstab

# setup networking
echo 'flashpointvm' >/etc/hostname
cat << 'EOF' >/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
	hostname flashpointvm
EOF

# setup required repos
echo 'https://dl-cdn.alpinelinux.org/alpine/edge/main' >/etc/apk/repositories
echo 'https://dl-cdn.alpinelinux.org/alpine/edge/community' >>/etc/apk/repositories
echo 'https://dl-cdn.alpinelinux.org/alpine/edge/testing' >>/etc/apk/repositories
apk update
apk add apache2 apache2-proxy php-apache2 fuse avfs unionfs-fuse sudo
sed -i 's/DEFAULT menu.c32/DEFAULT virt/g' /boot/extlinux.conf # boot directly into alpine

# install dev dependencies
apk add fuse-dev build-base git

# install php packages
apk add php-json php-openssl php-session php-pdo php-pdo_sqlite php-simplexml php-xml
wget -O/tmp/vendor.tar https://github.com/FlashpointProject/svcomposer/releases/download/18c0ebd/vendor.tar
tar -xvf /tmp/vendor.tar -C /var/www/localhost --exclude='vendor/silexlabs/amfphp/doc'

# install fuzzyfs
git clone https://github.com/XXLuigiMario/fuzzyfs.git /tmp/fuzzyfs
cd /tmp/fuzzyfs
make && make install

# setup htdocs
mkdir /root/base
git clone https://github.com/FlashpointProject/svroot.git /tmp/svroot
cd /tmp/svroot
find . -type f -not -path '*/.git*' -exec cp --parents {} /root/base \;
chmod -R 755 /root/base
rm /var/www/localhost/htdocs/index.html

# setup apache
rc-update add apache2 default # run apache2 on startup
echo 'apache ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' /etc/apache2/httpd.conf
sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/httpd.conf
sed -i 's/DirectoryIndex index.html/DirectoryIndex index.html index.htm index.php/g' /etc/apache2/httpd.conf
sed -i '/LogFormat.*common$/a\    LogFormat "%>s %r" flashpoint' /etc/apache2/httpd.conf
sed -i 's|logs/access.log combined|/dev/ttyS0 flashpoint env=!dontlog|g' /etc/apache2/httpd.conf
sed -i '/INCLUDES.*shtml$/a\    AddType x-world/x-xvr .xvr' /etc/apache2/httpd.conf
sed -i '/INCLUDES.*shtml$/a\    AddType x-world/x-svr .svr' /etc/apache2/httpd.conf
sed -i '/INCLUDES.*shtml$/a\    AddType x-world/x-vrt .vrt' /etc/apache2/httpd.conf
sed -i '/INCLUDES.*shtml$/a\    AddType application/x-httpd-php .phtml' /etc/apache2/httpd.conf
echo 'ServerName flashpointvm' >>/etc/apache2/httpd.conf
echo 'SetEnv force-response-1.0' >>/etc/apache2/httpd.conf # required for certain Shockwave games, thanks Tomy
echo 'SetEnvIf Remote_Addr "::1" dontlog' >>/etc/apache2/httpd.conf # disable logging of Apache's dummy connections
echo 'ProxyPreserveHost On' >>/etc/apache2/httpd.conf # keep "Host" header when proxying requests to legacy server

# hack: fix mime types for requests from legacy server
sed -i 's/exe dll com bat msi/exe dll bat msi/g' /etc/apache2/mime.types
sed -i 's|application/vnd.lotus-organizer|# application/vnd.lotus-organizer|g' /etc/apache2/mime.types

# setup gamezip service
mkdir /root/.avfs
cp /mnt/gamezip /etc/init.d
rc-update add gamezip default

# modify apache2 service dependencies
sed -i 's/need/need gamezip/' /etc/init.d/apache2
sed -i 's/after.*/after */' /etc/init.d/apache2

# Remove unneeded kernel modules.
# First, get a list of the needed ones. TODO: change this to FlashpointProject/flashpointvm
wget https://raw.githubusercontent.com/LindirQuenya/flashpointvm/master/needed_mods.txt -O root/needed_mods.txt
# Move to the right directory. We don't know kernel version, so we have to use a wildcard.
# If there is more than one kernel installed, we're done for.
cd /lib/modules/*/kernel/
# For each currently-installed module, (syntax modified from https://askubuntu.com/a/830791)
for i in $(find . -type f); do
  # Check if that module is not on the list of needed ones.
  # Btw, my list of needed ones might not be the bare minimum. I just stopped removing modules when it broke.
  if ! grep -qxFe "$i" /root/needed_mods.txt; then
    # If it's not on the list, remove it, and echo a nice message.
    echo "Deleting module: $i"
    rm "$i"
  fi
done

# build tools aren't needed anymore, remove them.
apk del build-base fuse-dev git

# cleanup
rm /root/needed_mods.txt
rm -rf /tmp/* /var/cache/apk/*
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
echo Done!
