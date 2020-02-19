# Installing Firecracker

In this document we will go over installing [Firecracker](https://firecracker-microvm.github.io/). 

> This manual covers installing Firecracker v0.21.0 on Arch Linux with kernel 5.4.15.

## Downloading the Software

Normally, we would have gone to the [release page](https://github.com/firecracker-microvm/firecracker/releases), however,
we can rely on Arch User Repository (AUR) for this installation.

On my machine I am using [yay](https://aur.archlinux.org/yay.git) as the AUR handler. 

To install and download Firecracker using `yay`: 

```bash
yay -S firecracker-bin
```

## Running the Firecracker Hello Image

This section heavily relies on [the getting started guide](https://github.com/firecracker-microvm/firecracker/blob/master/docs/getting-started.md). In this document we will assume that we want to run Firecracker just for testing purposes. 
If you intend to run Firecracker in production make sure that you properly secure its binary.

To run a Linux image on my intel 8th gen machine I need to download: 

1. A Linux [kernel image](https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin),
2. An [ext4 disc image](https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4) for rootfs.

To do this we run:

```bash
mkdir fctest
cd fctest
curl -fsSL https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin -o hello-vmlinux.bin
curl -fsSL https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4 -o hello-rootfs.ext4
```

To start a guest machine we can either use Firecracker's socket API or use a configuration file.
In this manual we have opted to use the API. 

We need two terminal sessions; one to run Firecracker from, and the other to issue commands against the API.

### Starting Firecracker

> To start off you can use [start.sh](https://github.com/zsadeghi/manuals/blob/master/firecracker/start.sh).

In the first session we want to make sure there is no existing socket file: 

```bash
rm -f /tmp/firecracker.socket
```

And start firecracker using this socket file:

```bash
firecracker --api-sock /tmp/firecracker.socket
```

### Starting the Image Using the API

> To run the image you can use [run.sh](https://github.com/zsadeghi/manuals/blob/master/firecracker/run.sh).

In the second terminal session, we first need to set the guest kernel:

```bash
kernel_path=$(pwd)"/hello-vmlinux.bin"

curl --unix-socket /tmp/firecracker.socket -i \
        -X PUT 'http://localhost/boot-source'   \
        -H 'Accept: application/json'           \
        -H 'Content-Type: application/json'     \
        -d "{
              \"kernel_image_path\": \"${kernel_path}\",
              \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
         }"
```

Next, we need to set the rootfs:

```bash
rootfs_path=$(pwd)"/hello-rootfs.ext4"
curl --unix-socket /tmp/firecracker.socket -i \
  -X PUT 'http://localhost/drives/rootfs' \
  -H 'Accept: application/json'           \
  -H 'Content-Type: application/json'     \
  -d "{
      \"drive_id\": \"rootfs\",
      \"path_on_host\": \"${rootfs_path}\",
      \"is_root_device\": true,
      \"is_read_only\": false
  }"
```

And finally, start the guest machine:

```bash
curl --unix-socket /tmp/firecracker.socket -i \
    -X PUT 'http://localhost/actions'       \
    -H  'Accept: application/json'          \
    -H  'Content-Type: application/json'    \
    -d '{
        "action_type": "InstanceStart"
     }'
```

### Using the Guest Machine

Going back to the first terminal session, we should see a login prompt.

To use the system we can use username `root` and password `root`.

To shut down the machine, we can run `reboot`, which would normally restart the system, but since
Fircracker does not implement power management it will simply shut the VM down.
