 # Installing Firecracker

In this document we will go over installing [Firecracker](https://firecracker-microvm.github.io/). 

> This manual covers installing Firecracker v0.21.1 on Ubuntu 19.10.

## Downloading the Software

I went to the [release page](https://github.com/firecracker-microvm/firecracker/releases), 

To install and download Firecracker I used the following command: 

```bash
curl -LOJ https://github.com/firecracker-microvm/firecracker/releases/download/v0.21.1/firecracker-v0.21.1
```
```bash
mv firecracker-v0.21.1 firecracker
```
```bash
chmod +x firecracker
```
Copy to $Path

```bash
sudo cp firecracker /usr/bin/
```
Gave myself read/write access to KVM

```bash
sudo setfacl -m u:${USER}:rw /dev/kvm
```

You can ceck if firecracker has been installed successfully

```bash
firecracker --help
```

## Setting up the VM

This section heavily relies on [the getting started guide](https://github.com/firecracker-microvm/firecracker/blob/master/docs/getting-started.md) and [the rootfs and kernel linux image guide](https://github.com/firecracker-microvm/firecracker/blob/master/docs/rootfs-and-kernel-setup.md).

If you intend to run Firecracker in production make sure that you properly secure its binary.

### Creating the Linux kernel image

The Linux Source code
```bash
git clone https://github.com/torvalds/linux.git linux.git
```
```bash
cd linux.git
```
Check out the Linux version you want to build:

```bash
git checkout v4.20
```
We now need to config a linux build. copy this [link](https://raw.githubusercontent.com/firecracker-microvm/firecracker/master/resources/microvm-kernel-x86_64.config) to `.config` 

```bash
vim .config
```
You can also use the interactive tool to create a config file:

```bash
make menuconfig
```
I got errors and resolved them by installation

```bash
sudo apt install libncurses-dev
```
```bash
sudo apt install bison
```
```bash
sudo apt install flex
```
Excuted `make` to start the build:

```bash
make vmlinux
```

#### Troubleshooting

I faced some errors when trying the above command, which I fixed as follows.

##### Compile errors

We wanted to compile the kernel from source code and by running the above command we faced the following error:

```
error: ‘-mindirect-branch’ and ‘-fcf-protection’ are not compatible
```

looking for this error on Google led me to [this kernel bug](https://bugs.launchpad.net/ubuntu/+source/gcc-9/+bug/1830961) and a comment suggested using gcc-8. To install gcc-8 alongside the existing gcc-9 we use the following commands:

```bash
sudo apt install gcc-8
```
```bash
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8
```
```bash
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 900 --slave /usr/bin/g++ g++ /usr/bin/g++-9
```
Finally to instruct the system to use gcc-8 as the default we run 

```bash
sudo update-alternatives --config gcc
```

##### Dependency failures

Attempting to compile again would result in some dependency failures for libssl which we can resolve by running:

```bash
sudo apt-get install libssl-dev
```

### Creating the `rootfs` Image

First create a volume file with `ext4` format:

```bash
dd if=/dev/zero of=rootfs.ext4 bs=1M count=50
```
Then we create an empty file system on the file that was created:

```bash
mkfs.ext4 rootfs.ext4
```
So create a path to mount the file:

```bash
mkdir /tmp/my-rootfs
```
Now mount the ext4 file over the directory we just created:

```bash
sudo mount rootfs.ext4 /tmp/my-rootfs
```
#### Install Docker

To install Docker for Ubuntu follow the instructions on the official [Docker website](https://docs.docker.com/engine/install/ubuntu/) 



### Starting Firecracker

To start a guest machine we can either use Firecracker's socket API or use a configuration file.
In this manual we have opted to use the API. 

We need two terminal sessions; one to run Firecracker from, and the other to issue commands against the API.


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
