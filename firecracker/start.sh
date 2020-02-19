#!/bin/bash

curl -fsSL https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin -o hello-vmlinux.bin
curl -fsSL https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4 -o hello-rootfs.ext4

rm -f /tmp/firecracker.socket

firecracker --api-sock /tmp/firecracker.socket
