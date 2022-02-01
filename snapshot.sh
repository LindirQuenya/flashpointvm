#!/bin/sh
qemu-system-i386 $QEMU_EXTRA_ARGS -display none -m 128 \
-net 'nic,model=virtio-net-pci' -net 'user,hostfwd=tcp::22500-:80' \
-monitor 'tcp:localhost:4445,server,nowait' -drive 'file=alpine.qcow2,if=virtio' &
pid=$!

while ! curl -sI 'http://127.0.0.1:22500/' >/dev/null; do
	echo 'VM not ready .. sleeping for 5 seconds' && sleep 5
done

echo 'apache is ready .. snapshot in 10 seconds' && sleep 10
echo 'savevm quick' | nc -q1 -w5 127.0.0.1 4445 >/dev/null
kill -TERM "$pid"

# Convert the image one last time, so that the snapshot data will get compressed too.
mv "alpine.qcow2" "alpine_temp.qcow2"
qemu-img convert -c -O qcow2 "alpine_temp.qcow2" "alpine.qcow2"
rm "alpine_temp.qcow2"
