#!/bin/sh
: ${ALPINE_MAKEVM:="https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/v0.7.0/alpine-make-vm-image"}
: ${APK_TOOLS_URI:="https://github.com/alpinelinux/apk-tools/releases/download/v2.10.3/apk-tools-2.10.3-x86-linux.tar.gz"}
: ${APK_TOOLS_SHA256:="afe41b98680e69bbf865a32e64dbac929030552bbf65a3397132350ab702da48"}
if [ "$(id -u)" -ne "0" ]; then
	echo "Please run as root"
	exit 1
fi
if ! command -v qemu-img >/dev/null; then
	echo "Please ensure qemu-utils is installed"
	exit 1
fi
COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null)
export APK_TOOLS_URI
export APK_TOOLS_SHA256
export COMMIT_HASH
tmp=$(mktemp -u /tmp/alpine.XXXXXX)
# Triple conversion was giving more consistent results, not entirely sure why.
# We pass the script through sed twice before running to add two more recent signing keys.
# They were extracted from the usr/share/apk/keys/x86 directory in the tar.gz archive at byte 407 of http://dl-cdn.alpinelinux.org/alpine/v3.14/main/x86/alpine-keys-2.4-r0.apk
wget -qO- "$ALPINE_MAKEVM" \
| sed 's|^alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub|alpine-devel@lists.alpinelinux.org-5243ef4b.rsa.pub:MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvNijDxJ8kloskKQpJdx+\\nmTMVFFUGDoDCbulnhZMJoKNkSuZOzBoFC94omYPtxnIcBdWBGnrm6ncbKRlR+6oy\\nDO0W7c44uHKCFGFqBhDasdI4RCYP+fcIX/lyMh6MLbOxqS22TwSLhCVjTyJeeH7K\\naA7vqk+QSsF4TGbYzQDDpg7+6aAcNzg6InNePaywA6hbT0JXbxnDWsB+2/LLSF2G\\nmnhJlJrWB1WGjkz23ONIWk85W4S0XB/ewDefd4Ly/zyIciastA7Zqnh7p3Ody6Q0\\nsS2MJzo7p3os1smGjUF158s6m/JbVh4DN6YIsxwl2OjDOz9R0OycfJSDaBVIGZzg\\ncQIDAQAB\nalpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub|g' \
| sed 's|^alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub|alpine-devel@lists.alpinelinux.org-61666e3f.rsa.pub:MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAlEyxkHggKCXC2Wf5Mzx4\\nnZLFZvU2bgcA3exfNPO/g1YunKfQY+Jg4fr6tJUUTZ3XZUrhmLNWvpvSwDS19ZmC\\nIXOu0+V94aNgnhMsk9rr59I8qcbsQGIBoHzuAl8NzZCgdbEXkiY90w1skUw8J57z\\nqCsMBydAueMXuWqF5nGtYbi5vHwK42PffpiZ7G5Kjwn8nYMW5IZdL6ZnMEVJUWC9\\nI4waeKg0yskczYDmZUEAtrn3laX9677ToCpiKrvmZYjlGl0BaGp3cxggP2xaDbUq\\nqfFxWNgvUAb3pXD09JM6Mt6HSIJaFc9vQbrKB9KT515y763j5CC2KUsilszKi3mB\\nHYe5PoebdjS7D1Oh+tRqfegU2IImzSwW3iwA7PJvefFuc/kNIijfS/gH/cAqAK6z\\nbhdOtE/zc7TtqW2Wn5Y03jIZdtm12CxSxwgtCF1NPyEWyIxAQUX9ACb3M0FAZ61n\\nfpPrvwTaIIxxZ01L3IzPLpbc44x/DhJIEU+iDt6IMTrHOphD9MCG4631eIdB0H1b\\n6zbNX1CXTsafqHRFV9XmYYIeOMggmd90s3xIbEujA6HKNP/gwzO6CDJ+nHFDEqoF\\nSkxRdTkEqjTjVKieURW7Swv7zpfu5PrsrrkyGnsRrBJJzXlm2FOOxnbI2iSL1B5F\\nrO5kbUxFeZUIDq+7Yv4kLWcCAwEAAQ==\nalpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub|g' \
| sh /dev/stdin -f qcow2 -c "$tmp" -s 512M setup.sh \
&& echo Shrinking image, please wait \
&& qemu-img convert -c -O qcow2 "$tmp" "start_$1" \
&& qemu-img convert -c -O qcow2 "start_$1" "mid_$1" \
&& qemu-img convert -c -O qcow2 "mid_$1" "$1" \
&& rm "start_$1" "mid_$1" \
&& [ $SUDO_USER ] && chown "$SUDO_USER": "$1"
rm "$tmp"
