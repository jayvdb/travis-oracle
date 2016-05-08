#!/bin/sh -e

test -u /usr/bin/sudo
SUDO_DISABLED=$?

[ -n "$ORACLE_FILE" ] || { echo "Missing ORACLE_FILE environment variable!"; exit 1; }
[ -n "$ORACLE_HOME" ] || { echo "Missing ORACLE_HOME environment variable!"; exit 1; }

ORACLE_RPM="$(basename $ORACLE_FILE .zip)"

cd "$(dirname "$(readlink -f "$0")")"

dpkg -s bc libaio1 rpm unzip > /dev/null 2>&1 ||
  ( sudo apt-get -qq update && sudo apt-get --no-install-recommends -qq install bc libaio1 rpm unzip )

if [ $SUDO_DISABLED -eq 0 ]; then
  df -B1 /dev/shm | awk 'END { if ($1 != "shmfs" && $1 != "tmpfs" || $2 < 2147483648) exit 1 }' ||
    ( sudo rm -r /dev/shm && sudo mkdir /dev/shm && sudo mount -t tmpfs shmfs -o size=2G /dev/shm )

  test -f /sbin/chkconfig ||
    ( echo '#!/bin/sh' | sudo tee /sbin/chkconfig > /dev/null && sudo chmod u+x /sbin/chkconfig )

  test -d /var/lock/subsys || sudo mkdir /var/lock/subsys
fi

unzip -j "$(basename $ORACLE_FILE)" "*/$ORACLE_RPM"

if [ $SUDO_DISABLED -eq 0 ]; then
  sudo rpm --install --nodeps --nopre "$ORACLE_RPM"

  echo 'OS_AUTHENT_PREFIX=""' | sudo tee -a "$ORACLE_HOME/config/scripts/init.ora" > /dev/null
  sudo usermod -aG dba $USER
  ( echo ; echo ; echo travis ; echo travis ; echo n ) | sudo AWK='/usr/bin/awk' /etc/init.d/oracle-xe configure
  IDENTIFIED_BY='EXTERNALLY'

else
  mkdir /home/travis/oracle
  rpm --install --nodeps --nopre --noscripts --notriggers  --relocate "/=$HOME/oracle/" "$ORACLE_RPM"

  ln -s /home/travis/oracle/u01/app/oracle/product/11.2.0/xe/lib/libclntsh.so.11.1 /home/travis/oracle/u01/app/oracle/product/11.2.0/xe/lib/libclntsh.so

  # this should check that LD_LIBRARY_PATH was set correctly
  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib; export LD_LIBRARY_PATH

  echo 'OS_AUTHENT_PREFIX=""' | tee -a "$ORACLE_HOME/config/scripts/init.ora" > /dev/null
  mkdir /home/travis/oracle/u01/app/oracle/oradata
  mkdir /home/travis/oracle/u01/app/oracle/diag
  sed -i "s/%hostname%/localhost/g" $ORACLE_HOME/network/admin/listener.ora
  sed -i "s/%port%/1521/g" $ORACLE_HOME/network/admin/listener.ora
  sed -i "s/\/u01/\/home\/travis\/u01/g" $ORACLE_HOME/network/admin/listener.ora

  sed -i "/^memory_target/d" $ORACLE_HOME/config/scripts/init.ora $ORACLE_HOME/config/scripts/initXETemp.ora $ORACLE_HOME/dbs/init.ora

  find $ORACLE_HOME/config -type f | xargs sed -i "s/\/u01/\/home\/travis\/u01/g"
  find $ORACLE_HOME/config -type f | xargs sed -i "s/%ORACLE_HOME%/\/home\/travis\/u01\/app\/oracle\/product\/11.2.0\/xe/g"

  mkdir -p $ORACLE_HOME/network/log $ORACLE_HOME/config/log
  touch $ORACLE_HOME/network/log/listener.log $ORACLE_HOME/config/log/CloneRmanRestore.log

  $ORACLE_HOME/bin/lsnrctl start
  sh -x $ORACLE_HOME/config/scripts/XE.sh
  cat > $ORACLE_HOME/config/scripts/create_travis_user.sql <<SQL
host $ORACLE_HOME/bin/orapwd file=$ORACLE_HOME/dbs/orapwXE password=oracle force=y
connect "SYS"/"oracle" as SYSDBA
alter user sys identified by "travis";
alter user system identified by "travis";
exit
SQL

  cat $ORACLE_HOME/config/scripts/create_travis_user.sql

  $ORACLE_HOME/bin/sqlplus /nolog @$ORACLE_HOME/config/scripts/create_travis_user.sql

  $ORACLE_HOME/bin/sqlplus sys/travis AS SYSDBA <<SQL
startup
SQL
IDENTIFIED_BY='BY "travis"'
fi

"$ORACLE_HOME/bin/sqlplus" -L -S sys/travis AS SYSDBA <<SQL
CREATE USER $USER IDENTIFIED $IDENTIFIED_BY;
GRANT CONNECT, RESOURCE TO $USER;
SQL
