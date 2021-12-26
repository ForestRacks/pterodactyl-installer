#!/bin/bash

set -e

# exit with error status code if user is not root
if [[ $EUID -ne 0 ]]; then
  echo "* This script must be executed with root privileges (sudo)." 1>&2
  exit 1
fi

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* Installing dependencies."
  # RHEL / CentOS / etc
  if [ -n "$(command -v yum)" ]; then
    yum update -y >> /dev/null 2>&1
  	yum -y install curl >> /dev/null 2>&1
  fi
  if [ -n "$(command -v apt-get)" ]; then
	  apt-get update -y >> /dev/null 2>&1
	  apt-get install -y snapd cron curl gzip >> /dev/null 2>&1
  fi
  # Check if curl was installed
  if ! [ -x "$(command -v curl)" ]; then
    echo "* curl is required in order for this script to work."
    echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
    exit 1
  fi
fi

output() {
  echo "* ${1}"
}

error() {
  COLOR_RED='\033[0;31m'
  COLOR_NC='\033[0m'

  echo ""
  echo -e "* ${COLOR_RED}ERROR${COLOR_NC}: $1"
  echo ""
}
basic=false
standard=false
advanced=false

panel=false
wings=false

output "Pterodactyl installation script"
output "This script is not associated with the official Pterodactyl Project."
output
output "DISCLAIMER: This script is a work in progress so it may have issues and rerunning this script can cause issues, we suggest reinstalling if you need to rerun."

output

while [ "$basic" == false ] && [ "$standard" == false ] && [ "$advanced" == false ]; do
  output "What would you like to do?"
  output "[1] Continue with the dummy installer."
  output "[2] Continue with the standard installer"
  output "[3] Continue with the advanced installer"

  echo -n "* Input 1-3: "
  read -r action

  case $action in
    1 )
      basic=true ;;
    2 )
      standard=true ;;
    3 )
      advanced=true ;;
    * )
      error "Invalid option" ;;
  esac
done

if [ "$basic" == false && "$standard" == false ]; then
  while [ "$panel" == false ] && [ "$wings" == false ]; do
    output "What would you like to do?"
    output "[1] Install the panel"
    output "[2] Install the daemon (Wings)"
    output "[3] Install both on the same machine"

    echo -n "* Input 1-3: "
    read -r action

    case $action in
      1 )
        panel=true ;;
      2 )
        wings=true ;;
      3 )
        panel=true
        wings=true ;;
      * )
        error "Invalid option" ;;
    esac
  done

  [ "$panel" == true ] && bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-panel.sh)
  [ "$wings" == true ] && bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-wings.sh)
elif [ "$standard" == true ]; then
  bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-standard.sh)
else
  bash <(curl -s https://raw.githubusercontent.com/ForestRacks/PteroInstaller/main/install-basic.sh)
fi