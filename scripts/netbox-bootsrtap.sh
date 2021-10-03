#!/bin/bash
# TODO: check selinux 

VERSION="$1"
if [ -z "$VERSION" ]
then
      VERSION="2.11.9"
fi

yum install -y firewalld

LOGFILE=/var/log/netbox_install.log >> $LOGFILE 2>>$LOGFILE
echo " ** Start script "`date` >> $LOGFILE 2>>$LOGFILE

# install Python 3
yum install python3 -y >> $LOGFILE 2>>$LOGFILE
yum install pip3 -y  >> $LOGFILE 2>>$LOGFILE
yum install expect -y  >> $LOGFILE 2>>$LOGFILE



#installation

# Install the repository RPM:
wget https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
yum install -y -i pgdg-redhat-repo-latest.noarch.rpm

# Install PostgreSQL:
yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

yum install postgresql13 postgresql13-server postgresql13-contrib postgresql13-libs -y >> $LOGFILE 2>>$LOGFILE

# systemctl enable postgresql
systemctl enable  postgresql-13

mkdir /opt/postgresql
mkdir /opt/postgresql/data
chown -R postgres:postgres /opt/postgresql
# selinux upddate for new postgresql location 
semanage fcontext -a -t postgresql_db_t "/opt/postgresql(/.*)?"
chcon -Rt postgresql_db_t /opt/postgresql/data

systemctl restart firewalld
firewall-cmd --add-service=postgresql --permanent
firewall-cmd --reload

sed -i 's/Environment=PGDATA=\/var\/lib\/pgsql\/13\/data/Environment=PGDATA=\/opt\/postgresql\/data/1' /usr/lib/systemd/system/postgresql-13.service



systemctl daemon-reload >> $LOGFILE 2>>$LOGFILE
systemctl start postgresql-13 >> $LOGFILE 2>>$LOGFILE
# sudo -u postgres initdb -D /opt/postgresql/data >> $LOGFILE 2>>$LOGFILE
# postgresql-setup --initdb
PGDATA=/opt/postgresql/data
/usr/pgsql-13/bin/postgresql-13-setup initdb

echo "local   all             all                                     peer" > /opt/postgresql/data/pg_hba.conf
echo "host    all             all             127.0.0.1/32            scram-sha-256" >> /opt/postgresql/data/pg_hba.conf
echo "host    all             all             ::1/128                 scram-sha-256" >> /opt/postgresql/data/pg_hba.conf

sleep 5 

systemctl restart postgresql-13 >> $LOGFILE 2>>$LOGFILE
sleep 5

#Within the shell, enter the following commands to create the database and user (role), substituting your own value for the password:
# Database Passowrd:
DataBasePassword=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16`

echo $
sudo -u postgres psql -c "CREATE DATABASE netbox;" >> $LOGFILE 2>>$LOGFILE
sudo -u postgres psql -c "CREATE USER netbox WITH PASSWORD '"$DataBasePassword"';" >> $LOGFILE 2>>$LOGFILE
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE netbox TO netbox;" >> $LOGFILE 2>>$LOGFILE

# install redis 5

yum install -y epel-release >> $LOGFILE 2>>$LOGFILE
yum install centos-release-scl -y 
yum --enablerepo=centos-sclo-rh -y install rh-redis5* >> $LOGFILE 2>>$LOGFILE

systemctl enable rh-redis5-redis
systemctl start rh-redis5-redis


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


wget https://raw.githubusercontent.com/skapy/netboxazure/master/scripts/upgrade.sh.patch
mv upgrade.sh.patch /opt/netbox/

cd /opt/netbox/

patch < upgrade.sh.patch >> $LOGFILE 2>>$LOGFILE

sudo /opt/netbox/upgrade.sh >> $LOGFILE 2>>$LOGFILE

# set netbox admin user password

source /opt/netbox/venv/bin/activate

#/usr/bin/expect <(cat << EOF
# spawn python3 /opt/netbox/netbox/manage.py createsuperuser
# expect "Username:"
#send "netbox\r"
#expect "Email address:"
#send "netbox@example.com\r"
#expect "Password:"
#send "netbox\r"
#expect "Password (again):"
#send "netbox\r"
#interact
#EOF
#)


cp -v /opt/netbox/contrib/*.service /etc/systemd/system/

cp /opt/netbox/contrib/gunicorn.py /opt/netbox/gunicorn.py


# create selfsigned cert

yum install openssl -y >> $LOGFILE 2>>$LOGFILE

mkdir /etc/ssl/private

#/usr/bin/expect <(cat << EOF
#spawn openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/netbox.key -out /etc/ssl/certs/netbox.crt
#expect "Country Name (2 letter code) [XX]:"
#send "US\r"
#expect "State or Province Name (full name) []:"
#send "Colorado\r"
#expect "Locality Name (eg, city) [Default City]:"
#send "Denver\r"
#expect "Organization Name (eg, company) [Default Company Ltd]:"
#send "CaciLabs\r"
#expect "Organizational Unit Name (eg, section) []:"
#send "IT\r"
#expect "Common Name (eg, your name or your server's hostname) []:"
#send "netbox.example.info\r"
#expect "Email Address []:"
#send "admin@netbox.example.info\r"
#interact
#EOF
#)

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/netbox.key -out /etc/ssl/certs/netbox.crt -subj "/C=US/ST=Colorado/L=Denver/O=CaciLabs/OU=IT Department/CN=netbox.example.com"

# instalil nginx

setsebool -P httpd_can_network_connect 1

yum install -y nginx

cp /opt/netbox/contrib/nginx.conf /etc/nginx/conf.d/

firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

systemctl enable nginx
systemctl restart nginx

# start netbox

systemctl daemon-reload
systemctl enable netbox netbox-rq
systemctl start netbox netbox-rq

echo " ** End script "`date` >> $LOGFILE 2>>$LOGFILE


