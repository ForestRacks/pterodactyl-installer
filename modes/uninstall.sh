#!/bin/bash

set -e

# Pterodactyl Installer 
# Copyright Forestracks 2022-2025

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/main.sh
  source <(curl -sSL "$GIT_REPO_URL"/lib/main.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

export RM_PANEL=false
export RM_WINGS=false

# --------------- Main functions --------------- #

ui() {
  if [ -d "/var/www/pterodactyl" ]; then
    output "Panel installation has been detected."
    echo -e -n "* Do you want to remove panel? (y/N): "
    read -r RM_PANEL_INPUT
    [[ "$RM_PANEL_INPUT" =~ [Yy] ]] && RM_PANEL=true
  fi

  if [ -d "/etc/pterodactyl" ]; then
    output "Wings installation has been detected."
    warning "This will remove all the servers!"
    echo -e -n "* Do you want to remove Wings (daemon)? (y/N): "
    read -r RM_WINGS_INPUT
    [[ "$RM_WINGS_INPUT" =~ [Yy] ]] && RM_WINGS=true
  fi

  if [ "$RM_PANEL" == false ] && [ "$RM_WINGS" == false ]; then
    error "Nothing to uninstall!"
    exit 1
  fi

  summary

  # confirm uninstallation
  echo -e -n "* Continue with uninstallation? (y/N): "
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    run_installer "uninstall"
  else
    error "Uninstallation aborted."
    exit 1
  fi
}

# ------------------ Variables ----------------- #

RM_PANEL="${RM_PANEL:-true}"
RM_WINGS="${RM_WINGS:-true}"

# ---------- Uninstallation functions ---------- #

rm_panel_files() {
  output "Removing panel files..."
  rm -rf /var/www/pterodactyl /usr/local/bin/composer
  [ "$OS" != "centos" ] && unlink /etc/nginx/sites-enabled/pterodactyl.conf
  [ "$OS" != "centos" ] && rm -f /etc/nginx/sites-available/pterodactyl.conf
  [ "$OS" != "centos" ] && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
  [ "$OS" == "centos" ] && rm -f /etc/nginx/conf.d/pterodactyl.conf
  systemctl restart nginx
  success "Removed panel files."
}

rm_docker_containers() {
  output "Removing docker containers and images..."

  docker system prune -a -f

  success "Removed docker containers and images."
}

rm_wings_files() {
  output "Removing wings files..."

  # stop and remove wings service
  systemctl disable --now wings
  rm -rf /etc/systemd/system/wings.service

  rm -rf /etc/pterodactyl /usr/local/bin/wings /var/lib/pterodactyl
  success "Removed wings files."
}

rm_services() {
  output "Removing services..."
  systemctl disable --now pteroq
  rm -rf /etc/systemd/system/pteroq.service
  case "$OS" in
  debian | ubuntu)
    systemctl disable --now redis-server
    ;;
  centos)
    systemctl disable --now redis
    systemctl disable --now php-fpm
    rm -rf /etc/php-fpm.d/www-pterodactyl.conf
    ;;
  esac
  success "Removed services."
}

rm_cron() {
  output "Removing cron jobs..."
  crontab -l | grep -vF "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" | crontab -
  success "Removed cron jobs."
}

rm_database() {
  output "Removing database..."
  valid_db=$(mariadb -u root -e "SELECT schema_name FROM information_schema.schemata;" | grep -v -E -- 'schema_name|information_schema|performance_schema|mysql')
  warning "Be careful! This database will be deleted!"
  if [[ "$valid_db" == *"panel"* ]]; then
    echo -n "* Database called panel has been detected. Is it the pterodactyl database? (y/N): "
    read -r is_panel
    if [[ "$is_panel" =~ [Yy] ]]; then
      DATABASE=panel
    else
      print_list "$valid_db"
    fi
  else
    print_list "$valid_db"
  fi
  while [ -z "$DATABASE" ] || [[ $valid_db != *"$database_input"* ]]; do
    echo -n "* Choose the panel database (to skip don't input anything): "
    read -r database_input
    if [[ -n "$database_input" ]]; then
      DATABASE="$database_input"
    else
      break
    fi
  done
  [[ -n "$DATABASE" ]] && mariadb -u root -e "DROP DATABASE $DATABASE;"
  # Exclude usernames User and root (Hope no one uses username User)
  output "Removing database user..."
  valid_users=$(mariadb -u root -e "SELECT user FROM mysql.user;" | grep -v -E -- 'user|root')
  warning "Be careful! This user will be deleted!"
  if [[ "$valid_users" == *"pterodactyl"* ]]; then
    echo -n "* User called pterodactyl has been detected. Is it the pterodactyl user? (y/N): "
    read -r is_user
    if [[ "$is_user" =~ [Yy] ]]; then
      DB_USER=pterodactyl
    else
      print_list "$valid_users"
    fi
  else
    print_list "$valid_users"
  fi
  while [ -z "$DB_USER" ] || [[ $valid_users != *"$user_input"* ]]; do
    echo -n "* Choose the panel user (to skip don't input anything): "
    read -r user_input
    if [[ -n "$user_input" ]]; then
      DB_USER=$user_input
    else
      break
    fi
  done
  [[ -n "$DB_USER" ]] && mariadb -u root -e "DROP USER $DB_USER@'127.0.0.1';"
  mariadb -u root -e "FLUSH PRIVILEGES;"
  success "Removed database and database user."
}

# --------------- Main functions --------------- #

perform_uninstall() {
  [ "$RM_PANEL" == true ] && rm_panel_files
  [ "$RM_PANEL" == true ] && rm_cron
  [ "$RM_PANEL" == true ] && rm_database
  [ "$RM_PANEL" == true ] && rm_services
  [ "$RM_WINGS" == true ] && rm_docker_containers
  [ "$RM_WINGS" == true ] && rm_wings_files

  return 0
}

# ------------------ Uninstall ----------------- #

summary() {
  print_brake 30
  output "Uninstall panel? $RM_PANEL"
  output "Uninstall wings? $RM_WINGS"
  print_brake 30
}

goodbye() {
  print_brake 62
  [ "$RM_PANEL" == true ] && output "Panel uninstallation completed"
  [ "$RM_WINGS" == true ] && output "Wings uninstallation completed"
  output "Thank you for using this script."
  print_brake 62
}

ui
perform_uninstall
goodbye
