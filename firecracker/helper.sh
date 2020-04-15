#!/bin/bash
# This bash script will start Firecracker in guest mode and can send the necessary commands
# to start the guest OS.
if [[ -z $(command -v firecracker) ]];
then
  echo "You need to first install Firecracker."
  exit 1
fi

directive="$1"

print_usage() {
  echo "Usage: $0 <directive>"
  echo ""
  echo "<directive> can be one of 'start', 'listen', 'help', or 'kill'"
}

print_flavors() {
    echo "Supported flavors are:"
    echo "  - alpine"
    echo "  - ubuntu-bionic"
}

send_command() {
  local v_resource="$1"
  local v_command="$2"
	curl -fsS --unix-socket /tmp/firecracker.socket -i \
        -X PUT "http://localhost/${v_resource}"   \
        -H 'Accept: application/json'           \
        -H 'Content-Type: application/json'     \
        -d "${v_command}" > /dev/null
}

user_get_home() {
 if [[ -n $(hash getent 2>&1) ]]; then
   if [[ -z $(hash finger 2>&1) ]]; then
     # We are in a macOS environment.
     finger "${USER}" | grep -E 'Directory:' | sed -E 's/^Directory: ([^ ]+) .*$/\1/'
   fi
 else
   getent passwd "${USER}" | cut -d: -f6
 fi
}


if [[ -z "${directive}" ]];
then
  echo "No directive specified."
  print_usage
  exit 1
fi

if [[ "${directive}" == "help" ]];
then
  target="$2"
  if [[ -z "${target}" ]];
  then
    print_usage
    echo "To get help on a specific directive, enter:"
    echo "$0 help <directive>"
    echo ""
    echo "To use this script, in one terminal session, use the <listen> directive,"
    echo "and in another session, use the <start> directive."
  fi
  if [[ "${target}" == "listen" ]];
  then
    echo "Starts the firecracker with an open socket so that we can communicate with it."
  elif  [[ "${target}" == "start" ]];
  then
    echo "Starts the Linux guest machine. This directive can take an argument:"
    echo "$0 start <flavor>"
    echo
    print_flavors
  elif  [[ "${target}" == "kill" ]];
  then
    echo "Kills the listening Firecracker instance, and the guest machine on it."
  else
    echo "Unknown directive ${target}"
    exit 1
  fi
  exit 0
elif [[ "${directive}" == "start" ]];
then
  flavor="$2"
  if [[ -z "${flavor}" ]];
  then
    echo "You need to select a flavor."
    echo ""
    print_flavors
    exit 1
  fi
  flavor_name=""
  if [[ "${flavor}" == "alpine" ]];
  then
    flavor_name="Linux Alpine, running on kernel v4.20"
  elif [[ "${flavor}" == "ubuntu-bionic" ]];
  then
    flavor_name="Ubuntu Bionic Beaver (18.04 LTS), running on kernel 4.15"
  else
    echo "Unknown flavor ${flavor}"
    echo ""
    print_flavors
    exit 1
  fi
  if [[ ! -d "$(user_get_home)/.firecracker-starter/${flavor}" ]];
  then
    mkdir -p "$(user_get_home)/.firecracker-starter/${flavor}"
  fi
  if [[ ! -f "$(user_get_home)/.firecracker-starter/${flavor}/vmlinux" ]];
  then
    echo "Downloading the necessary Linux kernel image"
    curl -fsSL "https://files.thegirlwho.codes/linux/${flavor}/vmlinux" -o "$(user_get_home)/.firecracker-starter/${flavor}/vmlinux"
  fi
  if [[ ! -f "$(user_get_home)/.firecracker-starter/${flavor}/rootfs.ext4" ]];
  then
    echo "Downloading the necessary distribution rootfs file"
    curl -fsSL "https://files.thegirlwho.codes/linux/${flavor}/rootfs.ext4" -o "$(user_get_home)/.firecracker-starter/${flavor}/rootfs.ext4"
  fi
  echo "Setting the kernel path on the server"
  send_command "boot-source" "{
              \"kernel_image_path\": \"$(user_get_home)/.firecracker-starter/${flavor}/vmlinux\",
              \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
         }"
  echo "Setting the rootfs image"
  send_command "drives/rootfs" "{
     		 \"drive_id\": \"rootfs\",
     		 \"path_on_host\": \"$(user_get_home)/.firecracker-starter/${flavor}/rootfs.ext4\",
     		 \"is_root_device\": true,
     		 \"is_read_only\": false
 	     }"
  echo "Starting the guest OS: ${flavor_name}"
  send_command "actions" '{
        	"action_type": "InstanceStart"
    	 }'
elif [[ "${directive}" == "kill" ]];
then
  echo "Turning down the guest machine"
  send_command "actions" '{
                "action_type": "SendCtrlAltDel"
         }'
elif [[ "${directive}" == "listen" ]];
then
	echo "Starting firecracker guest server"
	rm -f /tmp/firecracker.socket
	firecracker --api-sock /tmp/firecracker.socket
else
  echo "Unknown directive: ${directive}"
  exit 1
fi
