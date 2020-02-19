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

