FROM centos:centos7
MAINTAINER Stephen Butcher stephen.butcher@redhound.net, Ben Dalby ben.dalby@redhound.net

# Copy only files required for the following RUN commands (leverage Docker caching)
COPY container-files/etc/yum.repos.d/* /etc/yum.repos.d/

RUN \
    yum update -y && \
    yum install -y epel-release && \
    yum install -y MariaDB-server MariaDB-connect-engine MariaDB-compat hostname net-tools pwgen freetds && \
    yum clean all && \
    rm -rf /var/lib/mysql/*

# Add all remaining files to the container
COPY container-files /
RUN chmod 755 /etc/my.cnf.d /etc/yum.repos.d
RUN chmod 644 /etc/yum.repos.d/mariadb.repo /etc/my.cnf.d/*.cnf
RUN echo "">> /etc/odbcinst.ini
RUN echo "[FreeTDS]">> /etc/odbcinst.ini
RUN echo "Description=FreeTDS MSSQL Driver">> /etc/odbcinst.ini
RUN echo "Driver=/usr/lib64/libtdsodbc.so.0">> /etc/odbcinst.ini
RUN echo "Setup=/usr/lib64/libtdsS.so.2">> /etc/odbcinst.ini
RUN echo "">> /etc/odbcinst.ini
RUN odbcinst -i -d -f /etc/odbcinst.ini 

# Add VOLUME to allow backup of data

VOLUME ["/var/lib/mysql"]

# Set TERM env to avoid mysql client error message "TERM environment variable not set" when running from inside the container
ENV TERM xterm

EXPOSE 3306
CMD ["/run.sh"]
