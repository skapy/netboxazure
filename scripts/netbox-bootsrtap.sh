# TODO: add custom script
VERSION="$1"
LOGFILE=/var/log/netbox_install.log >> $LOGFILE 2>>$LOGFILE
echo " ** Start script "`date` >> $LOGFILE 2>>$LOGFILE

# install from SCLo repos
yum install python3 -y >> $LOGFILE 2>>$LOGFILE

yum install pip3 -y  >> $LOGFILE 2>>$LOGFILE



#installation

# Install the repository RPM:
sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Install PostgreSQL:
sudo yum install -y postgresql96-server lib-devel

yum install postgresql96 postgresql96-server postgresql96-contrib postgresql96-libs -y >> $LOGFILE 2>>$LOGFILE 
yum install postgresql96 postgresql96-server postgresql96-contrib postgresql96-libs -y >> $LOGFILE 2>>$LOGFILE


# yum install -y postgresql postgresql-server

# systemctl enable postgresql
systemctl enable  postgresql-9.6

mkdir /opt/postgresql
mkdir /opt/postgresql/data
chown -R postgres:postgres /opt/postgresql
# selinux upddate for new postgresql location 
semanage fcontext -a -t postgresql_db_t "/opt/postgresql(/.*)?"
chcon -Rt postgresql_db_t /opt/postgresql/data
firewall-cmd --add-service=postgresql --pernament

sed -i 's/Environment=PGDATA=\/var\/lib\/pgsql\/9.6\/data/Environment=PGDATA=\/opt\/postgresql\/data/1' /usr/lib/systemd/system/postgresql-9.6.service



systemctl daemon-reload >> $LOGFILE 2>>$LOGFILE
systemctl start postgresql-9.6 >> $LOGFILE 2>>$LOGFILE
# sudo -u postgres initdb -D /opt/postgresql/data >> $LOGFILE 2>>$LOGFILE
# postgresql-setup --initdb
PGDATA=/opt/postgresql/data
/usr/pgsql-9.6/bin/postgresql96-setup initdb

echo "local   all             all                                     md5" > /opt/postgresql/data/pg_hba.conf
echo "host    all             all             127.0.0.1/32            md5" >> /opt/postgresql/data/pg_hba.conf
echo "host    all             all             ::1/128                 md5" >> /opt/postgresql/data/pg_hba.conf



systemctl restart postgresql-9.6 >> $LOGFILE 2>>$LOGFILE
sleep 5

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


sudo wget https://github.com/netbox-community/netbox/archive/v$VERSION.tar.gz >> $LOGFILE 2>>$LOGFILE
sudo tar -xzf v$VERSION.tar.gz -C /opt >> $LOGFILE 2>>$LOGFILE
sudo ln -s /opt/netbox-$VERSION/ /opt/netbox

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
# sudo sh -c "echo 'django-storages' >> /opt/netbox/local_requirements.txt"

pip3 install -r /opt/netbox-$$VERSION/requirements.txt --upgrade >> $LOGFILE 2>>$LOGFILE

python3 -c "import sys; print('\n'.join(sys.path))" >> $LOGFILE 2>>$LOGFILE

# . /etc/profile 
# . /etc/profile.d/$PYTHONV.sh
# sed -i "s/python3/\/opt\/rh\/rh-$PYTHONV\/root\/usr\/bin\/python3/1" /opt/netbox/upgrade.sh

spleep 5
sudo /opt/netbox/upgrade.sh >> $LOGFILE 2>>$LOGFILE

echo " ** End script "`date` >> $LOGFILE 2>>$LOGFILE
