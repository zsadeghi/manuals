#!/bin/bash
# This bash script will start Firecracker in guest mode and can send the necessary commands
# to start the guest OS.
if [[ -z $(command -v firecracker) ]];
then
  echo "You need to first install Firecracker."
  exit 1
fi

socket_file="${FIRECRACKER_SOCKET_FILE}"
[[ -z "${socket_file}" ]] && socket_file="/tmp/firecracker.socket" 
directive="$1"

print_usage() {
  echo "Usage: $0 <directive>"
  echo ""
  echo "<directive> can be one of 'start', 'listen', 'help', 'kill', or 'run'"
}

print_flavors() {
    echo "Supported flavors are:"
    echo "  - alpine"
    echo "  - ubuntu-bionic"
}

send_command() {
  local v_resource="$1"
  local v_command="$2"
	curl -fsS --unix-socket ${socket_file} -i \
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

check_flavor() {
  local flavor="$1"
  if [[ -z "${flavor}" ]];
  then
    >&2 echo "You need to select a flavor."
    >&2 echo ""
    >&2 print_flavors
    exit 1
  fi
  local flavor_name=""
  if [[ "${flavor}" == "alpine" ]];
  then
    flavor_name="Linux Alpine, running on kernel v4.20"
  elif [[ "${flavor}" == "ubuntu-bionic" ]];
  then
    flavor_name="Ubuntu Bionic Beaver (18.04 LTS), running on kernel 4.15"
  else
    >&2 echo "Unknown flavor ${flavor}"
    >&2 echo ""
    >&2 print_flavors
    exit 1
  fi
  echo "${flavor_name}"
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
    echo "To use this script, if you have 'screen' installed, you can run:"
    echo
    echo "    $0 run <flavor>"
    echo
    echo "See '$0 help run' for more info."
    echo
    echo "If you do not have screen installed, or if you want more controll"
    echo "then, in one terminal session, use the <listen> directive:"
    echo "   $0 listen"
    echo "and in another session, use the <start> directive:"
    echo "   $0 start <flavor>"
  fi
  if [[ "${target}" == "listen" ]];
  then
    echo "Starts the firecracker with an open socket so that we can communicate with it."
  elif  [[ "${target}" == "start" ]];
  then
    echo "Usage: $0 start <flavor>"
    echo
    echo "Starts the Linux guest machine. This directive can take an argument:"
    echo
    print_flavors
  elif  [[ "${target}" == "kill" ]];
  then
    echo "Usage: $0 kill"
    echo ""
    echo "Kills the listening Firecracker instance, and the guest machine on it."
  elif [[ "${target}" == "run" ]];
  then
    echo "Runs the indicated Linux flavor in the same TTY session using the 'start' and 'listen' commands combined."
    echo ""
    echo "Usage: $0 run <flavor> [options]"
    echo ""
    echo "For a list of supported flavors see: $0 help start"
  else
    echo "Unknown directive ${target}"
    exit 1
  fi
  exit 0
elif [[ "${directive}" == "start" ]];
then
  flavor="$2"
  flavor_name=$(check_flavor "${flavor}")
  if [[ -z "${flavor_name}" ]];
  then
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
	rm -f ${socket_file}
	firecracker --api-sock ${socket_file}
elif [[ "${directive}" == "run" ]];
then
  if [[ -z "$(command -v screen)" ]];
  then
    echo "You need to install screen to be able to do this."
    echo "On Ubuntu, you can get screen by typing:"
    echo "    sudo apt install screen"
    exit 1
  fi
  export FIRECRACKER_SOCKET_FILE="$(mktemp)"
  flavor="$2"
  flavor_name=$(check_flavor "${flavor}")
  opt_detach=0
  if [[ -z "${flavor_name}" ]];
  then
    exit 1
  fi
  shift
  shift
  while [[ $# -gt 0 ]];
  do
    opt="$1"
    shift;
    case "${opt}" in
      -d|--detach)
	opt_detach=1
      ;;
      *)
        echo "Unsupported option: ${opt}"
	exit 1
      ;;
    esac
  done
  screen_name="$(basename "${FIRECRACKER_SOCKET_FILE}")"
  screen -dmS "${screen_name}" $0 listen
  $0 start "${flavor}"
  if [[ ${opt_detach} == 0 ]];
  then
    screen -x "${screen_name}"
  else
    echo "To attach to the guest OS, type:"
    echo "    screen -x ${screen_name}"
    echo "To stop the session type:"
    echo "    screen -S ${screen_name} -X quit"
  fi
else
  echo "Unknown directive: ${directive}"
  exit 1
fi
