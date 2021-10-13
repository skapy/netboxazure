#!/bin/bash
# TODO: check selinux 

VERSION="$1"
if [ -z "$VERSION" ]
then
      VERSION="2.11.9"
fi

yum install -y firewalld wget unzip

LOGFILE=/var/log/netbox_install.log >> $LOGFILE 2>>$LOGFILE
echo " ** Start script "`date` >> $LOGFILE 2>>$LOGFILE

# install Python 3
yum install python3 -y >> $LOGFILE 2>>$LOGFILE
yum install pip3 -y  >> $LOGFILE 2>>$LOGFILE
yum install expect -y  >> $LOGFILE 2>>$LOGFILE



#installation

# Install the repository RPM:
# wget https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
# yum install -y -i pgdg-redhat-repo-latest.noarch.rpm

# Install PostgreSQL:
yum install -y --nogpgcheck https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

yum install postgresql13 postgresql13-server postgresql13-contrib postgresql13-libs pgaudit15_13 pgauditlogtofile_13 -y >> $LOGFILE 2>>$LOGFILE

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

sed -i 's/PGDATA=\/var\/lib\/pgsql\/13\/data/PGDATA=\/opt\/postgresql\/data/1' /var/lib/pgsql/.bash_profile





systemctl daemon-reload >> $LOGFILE 2>>$LOGFILE
systemctl start postgresql-13 >> $LOGFILE 2>>$LOGFILE
# sudo -u postgres initdb -D /opt/postgresql/data >> $LOGFILE 2>>$LOGFILE
# postgresql-setup --initdb
PGDATA=/opt/postgresql/data
/usr/bin/postgresql-13-setup initdb

echo "local   all             all                                     scram-sha-256" > $PGDATA/pg_hba.conf
echo "host    all             all             127.0.0.1/32            scram-sha-256" >> $PGDATA/pg_hba.conf
echo "host    all             all             ::1/128                 scram-sha-256" >> $PGDATA/pg_hba.conf

# F-79285r3_fix
echo "pgaudit.log_catalog='on'" >> $PGDATA/postgresql.conf
echo "pgaudit.log_level='log'" >> $PGDATA/postgresql.conf
echo "pgaudit.log_parameter='on'" >> $PGDATA/postgresql.conf
echo "pgaudit.log_statement_once='off'" >> $PGDATA/postgresql.conf
echo "pgaudit.log='all, -misc'" >> $PGDATA/postgresql.conf

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


# 

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

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/netbox.key -out /etc/ssl/certs/netbox.crt -subj "/C=US/ST=Colorado/L=Denver/O=CaciLabs/OU=IT Department/CN=netbox.example.com"

# instalil nginx

setsebool -P httpd_can_network_connect 1

yum install -y nginx

cp /opt/netbox/contrib/nginx.conf /etc/nginx/conf.d/

sed -i '/listen       [::]:80;/d' /etc/nginx/nginx.conf

firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

systemctl enable nginx
systemctl restart nginx

# start netbox

systemctl daemon-reload
systemctl enable netbox netbox-rq
systemctl start netbox netbox-rq


# Create an Ansible script for DISA STIG

# Install Ansible

yum install -y ansible 

# install openscap

yum install -y openscap scap-security-guide 

# Create an Ansible Script
scp /usr/share/xml/scap/ssg/content/ssg-rhel7-ds.xml /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml
sed -i 's/redhat:enterprise_linux:7/centos:centos:7/g' /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml

oscap xccdf generate fix --fix-type ansible --profile xccdf_org.ssgproject.content_profile_rhelh-stig --output stig-rhel7-role.yml --fetch-remote-resources /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml

# Create localhost inventory file 

echo "[nodes]" > inventory.ini
echo "localnode ansible_user=root ansible_host=127.0.0.1 ansible_connection=local" >> inventory.ini

# Execute Ansible Script

echo "-------- Execute Ansible Script --------------" >> $LOGFILE

# ansible-playbook -i inventory.ini stig-rhel7-role.yml >> $LOGFILE 2>>$LOGFILE

# Generate a linux report

oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_rhelh-stig --report /tmp/report.html /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml
# oscap xccdf eval --remediate --profile xccdf_org.ssgproject.content_profile_rhelh-stig --report /tmp/report.html /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml

# Generate a PostgreSQL report

wget https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_PGS_SQL_9-x_V2R2_STIG.zip

unzip U_PGS_SQL_9-x_V2R2_STIG.zip

oscap xccdf eval --profile MAC-1_Classified --report /tmp/postgresql_report.html U_PGS_SQL_9-x_V2R2_Manual_STIG/U_PGS_SQL_9-x_STIG_V2R2_Manual-xccdf.xml


echo " ** End script "`date` >> $LOGFILE 2>>$LOGFILE


