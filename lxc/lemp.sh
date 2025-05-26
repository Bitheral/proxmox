#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 bitheral
# Author: bitheral
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

APP="debian"
var_tags="${var_tags:-os}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /var ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating $APP LXC"
  $STD apt-get update
  $STD apt-get -y upgrade
  msg_ok "Updated $APP LXC"
  exit
}

start
build_container
description

# ---- LEMP INSTALLATION START ----
msg_info "Installing LEMP Stack"
lxc-attach -n $CTID -- bash -c "
  dpkg -l | grep php | tee packages.txt >/dev/null &&
  apt-get install -qq -y apt-transport-https &&
  curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg &&
  sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' &&
  apt-get update -qq &&
  DEBIAN_FRONTEND=noninteractive apt-get install -qq -y \
    nginx mariadb-server php8.3-fpm php8.3-mysql php8.3-cli \
    php8.3-curl php8.3-mbstring php8.3-xml unzip &&
  systemctl enable nginx >/dev/null &&
  systemctl enable mariadb >/dev/null &&
  systemctl enable php8.3-fpm >/dev/null

#  dpkg -l | grep php | tee packages.txt &&
#  apt install apt-transport-https &&
#  curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg &&
#  sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' &&
#  apt-get update &&
#  apt-get install -y nginx mariadb-server php8.3-fpm php8.3-mysql php8.3-cli php8.3-curl php8.3-mbstring php8.3-xml unzip &&
#  systemctl enable nginx &&
#  systemctl enable mariadb &&
#  systemctl enable php8.3-fpm
"
msg_ok "Installed LEMP Stack"

msg_info "Creating PHP Info Page"
lxc-attach -n $CTID -- bash -c "
  echo '<?php phpinfo(); ?>' > /var/www/html/info.php &&
  sed -i 's/index index.html/index index.php index.html/' /etc/nginx/sites-available/default &&
  sed -i '/location ~ \\.php\$ {/,+5s/#//' /etc/nginx/sites-available/default &&
  sed -i '/location ~ \\.php\$ {/,+5s/# //' /etc/nginx/sites-available/default &&
  systemctl restart nginx
"
msg_ok "PHP Info Page Created and Nginx Restarted"
# ---- LEMP INSTALLATION END ----


msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}/${CL}"
