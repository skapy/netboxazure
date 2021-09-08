# TODO: add custom script
LOGFILE=/var/log/nexbox_install.log >> $LOGFILE 2>>$LOGFILE
echo " ** Start script "`date` >> $LOGFILE 2>>$LOGFILE

# install from SCLo repos
yum install centos-release-scl wget -y >> $LOGFILE 2>>$LOGFILE

# install Python 3.8 from SCLo
yum --enablerepo=centos-sclo-rh -y install rh-python38 >> $LOGFILE 2>>$LOGFILE

echo "source /opt/rh/rh-python38/enable" > /etc/profile.d/python38.sh
echo "export X_SCLS=\"\`scl enable rh-python38 'echo \$X_SCLS'\`\"" >> /etc/profile.d/python38.sh

# or run "

source /opt/rh/rh-python38/enable


#installation
yum install -y postgresql postgresql-server

semanage fcontext -a -t postgresql_db_t "/opt/postgresql(/.*)?"

systemctl enable postgresql

mkdir /opt/postgresql
mkdir /opt/postgresql/data
chown -R postgres:postgres /opt/postgresql

sed -i 's/Environment=PGDATA=\/var\/lib\/pgsql\/data/Environment=PGDATA=\/opt\/postgresql\/data/1' /usr/lib/systemd/system/postgresql.service



systemctl daemon-reload >> $LOGFILE 2>>$LOGFILE
systemctl start postgresql.service >> $LOGFILE 2>>$LOGFILE

#Within the shell, enter the following commands to create the database and user (role), substituting your own value for the password:
# Database Passowrd:
DataBasePassword=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16`

echo $
sudo -u postgres psql -c "CREATE DATABASE netbox;" >> $LOGFILE 2>>$LOGFILE
sudo -u postgres psql -c "CREATE USER netbox WITH PASSWORD '"$DataBasePassword"';" >> $LOGFILE 2>>$LOGFILE
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;" >> $LOGFILE 2>>$LOGFILE

# install redis

yum install -y epel-release >> $LOGFILE 2>>$LOGFILE

yum install -y redis >> $LOGFILE 2>>$LOGFILE
systemctl enable redis
systemctl start redis


# install netbox

pip install --upgrade pip >> $LOGFILE 2>>$LOGFILE


sudo wget https://github.com/netbox-community/netbox/archive/v3.0.1.tar.gz >> $LOGFILE 2>>$LOGFILE
sudo tar -xzf v3.0.1.tar.gz -C /opt >> $LOGFILE 2>>$LOGFILE
sudo ln -s /opt/netbox-3.0.1/ /opt/netbox

# create netbox user

sudo adduser --system netbox
sudo cp /opt/netbox/netbox/netbox/configuration.example.py /opt/netbox/netbox/netbox/configuration.py

sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = \['*'\]/1" /opt/netbox/netbox/netbox/configuration.py
sed -i "s/'USER': '',               # PostgreSQL/'USER': 'netbox',         # PostgreSQL/1" /opt/netbox/netbox/netbox/configuration.py
sed -i "s/'PASSWORD': '',           # PostgreSQL/'PASSWORD': '"$DataBasePassword"', # PostgreSQL/1" /opt/netbox/netbox/netbox/configuration.py

sed -i "s/SECRET_KEY = ''/SECRET_KEY = '"`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c50`"'/1" /opt/netbox/netbox/netbox/configuration.py

sudo chown --recursive netbox /opt/netbox/netbox/media/


# install

sudo sh -c "echo 'napalm' >> /opt/netbox/local_requirements.txt"
sudo sh -c "echo 'django-storages' >> /opt/netbox/local_requirements.txt"


sudo /opt/netbox/upgrade.sh >> $LOGFILE 2>>$LOGFILE

echo " ** End script "`date` >> $LOGFILE 2>>$LOGFILE
