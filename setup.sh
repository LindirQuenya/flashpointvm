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
apk add apache2 apache2-proxy php-apache2 fuse unionfs-fuse libarchive libgcc libstdc++
sed -i 's/DEFAULT menu.c32/DEFAULT virt/g' /boot/extlinux.conf # boot directly into alpine

# install dev dependencies
apk add fuse-dev build-base git libarchive-dev

# install php packages
apk add php-json php-openssl php-session php-pdo php-pdo_sqlite php-simplexml php-xml
wget -O/tmp/vendor.tar https://github.com/FlashpointProject/svcomposer/releases/download/18c0ebd/vendor.tar
tar -xvf /tmp/vendor.tar -C /var/www/localhost --exclude='vendor/silexlabs/amfphp/doc'

# Install fuse-archive
git clone https://github.com/google/fuse-archive.git /tmp/fuse-archive
cd /tmp/fuse-archive
mkdir -p '/usr/local/sbin'
g++ -O3 src/main.cc `pkg-config libarchive fuse --cflags --libs` -o "/usr/local/bin/fuse-archive"

# Install fpmountd
wget -O "/usr/local/bin/fpmountd" "https://github.com/FlashpointProject/flashpointvm-mount-daemon/releases/download/e669fd4/flashpointvm-mount-daemon_i686-unknown-linux-musl_qemu"
chmod +x "/usr/local/bin/fpmountd"

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
echo '<FilesMatch "\.(blz)$">' >>/etc/apache2/httpd.conf # work around buggy emblaze plugin
echo 'Header unset ETag' >>/etc/apache2/httpd.conf
echo '</FilesMatch>' >>/etc/apache2/httpd.conf
# hack: fix mime types for requests from legacy server
sed -i 's/exe dll com bat msi/exe dll bat msi/g' /etc/apache2/mime.types
sed -i 's|application/vnd.lotus-organizer|# application/vnd.lotus-organizer|g' /etc/apache2/mime.types

# setup gamezip service
cp /mnt/gamezip /etc/init.d
rc-update add gamezip default

# setup fpmountd service
cp /mnt/fpmountd /etc/init.d
rc-update add fpmountd default

# modify apache2 service dependencies
sed -i 's/need/need gamezip/' /etc/init.d/apache2
sed -i 's/after.*/after */' /etc/init.d/apache2

# Remove disabled apache modules.
# Move to the right directory.
cd /usr/lib/apache2/
# First, get a list of uncommented modules. (Syntax explanation later.)
cat /etc/apache2/httpd.conf /etc/apache2/conf.d/*.conf | grep 'LoadModule.*so$' | grep -v \# | cut -d '/' -f2 > /root/uncommented_apache_mods.txt
# We get a list of disabled modules from the commented LoadModule lines in httpd.conf
# Format: "LoadModule some_module modules/mod_some.so" => Module is at /usr/lib/apache2/mod_some.so
# The grep translates to: anything, then 'LoadModule', then anything, then 'so' at the end of the line.
# We want the part after the slash. Then we check that it's not also somewhere else, uncommented.
for i in $(cat /etc/apache2/httpd.conf /etc/apache2/conf.d/*.conf | grep 'LoadModule.*so$' | grep \# | cut -d '/' -f2); do
  # Check that the module isn't also loaded uncommented somewhere else. (Looking at you, mod_negotiation.)
  if ! grep -qxFe "$i" /root/uncommented_apache_mods.txt; then
    echo Deleting apache module: /usr/lib/apache2/"$i"
    # Using -f turns off error messages if a file isn't found.
    rm -f /usr/lib/apache2/"$i"
  fi
done

# Remove unneeded kernel modules.
# First, get a list of the needed ones.
cp /mnt/needed_mods.txt /root/needed_mods.txt
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
apk del build-base fuse-dev git libarchive-dev

# cleanup
rm /root/needed_mods.txt
rm /root/uncommented_apache_mods.txt
rm -rf /tmp/* /var/cache/apk/*
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
echo Done!
