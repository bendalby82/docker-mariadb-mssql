#!/bin/sh


#########################################################
# Check in the loop (every 1s) if the database backend
# service is already available for connections.
#########################################################
function wait_for_db() {
  local RET=1
  set +e
  while [[ RET -ne 0 ]]; do
    mysql -uroot -e "status" > /dev/null 2>&1
    RET=$?
    if [[ RET -ne 0 ]]; then echo "Waiting for DB service..." && sleep 1; fi
  done
  set -e
}


#########################################################
# Check in the loop (every 1s) if the database backend
# service is already available for connections.
#########################################################
function terminate_db() {
  local pid=$(cat $VOLUME_HOME/mysql.pid)
  echo "Caught SIGTERM signal, exiting DB process (pid $pid)..."
  kill -TERM $pid
  
  while true; do
    if tail $ERROR_LOG | grep -s -E "mysqld .+? ended" $ERROR_LOG; then break; else sleep 0.5; fi
  done
}


#########################################################
# Cals `mysql_install_db` if empty volume is detected.
# Globals:
#   $VOLUME_HOME
#   $ERROR_LOG
#########################################################
function install_db() {
  if [ ! -d $VOLUME_HOME/mysql ]; then
    echo "=> An empty/uninitialized MariaDB volume is detected in $VOLUME_HOME"
    echo "=> Installing MariaDB..."
    mysql_install_db --user=mysql
    echo "=> Done!"
  else
    echo "=> Using an existing volume of MariaDB."
  fi
  
  # Move previous error log (which might be there from previously running container
  # to different location. We do that to have error log from the currently running
  # container only.
  if [ -f $ERROR_LOG ]; then
    echo "----------------- Previous error log -----------------"
    tail -n 20 $ERROR_LOG
    echo "----------------- Previous error log ends -----------------" && echo
    mv -f $ERROR_LOG "${ERROR_LOG}.old";
  fi

  touch $ERROR_LOG
}

#########################################################
# Check in the loop (every 1s) if the database backend
# service is already available for connections.
# Globals:
#   $MARIADB_USER
#   $MARIADB_PASS
#########################################################
function create_admin_user() {
  wait_for_db
  
  local users=$(mysql -s -e "SELECT count(User) FROM mysql.user WHERE User='$MARIADB_USER'")
  if [[ $users == 0 ]]; then
    echo "=> Creating MariaDB user '$MARIADB_USER' with '$MARIADB_PASS' password."
    mysql -uroot -e "CREATE USER '$MARIADB_USER'@'%' IDENTIFIED BY '$MARIADB_PASS'"
  else
    echo "=> User '$MARIADB_USER' exists, updating its password to '$MARIADB_PASS'"
    mysql -uroot -e "SET PASSWORD FOR '$MARIADB_USER'@'%' = PASSWORD('$MARIADB_USER')"
  fi;
  
  mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '$MARIADB_USER'@'%' WITH GRANT OPTION"
  mysql -uroot -e "FLUSH PRIVILEGES"

  echo "========================================================================"
  echo "You can now connect to this MariaDB Server using:                       "
  echo "                                                                        "
  echo "    mysql -u$MARIADB_USER -p$MARIADB_PASS -h<host>                      "
  echo "                                                                        "
  echo "For security reasons, remember to change the above password.            "
  echo "MariaDB user 'root' has no password but only allows local connections   "
  echo "========================================================================"
}

function show_db_status() {
  wait_for_db
  mysql -uroot -e "status"
}