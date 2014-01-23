# VERSION 0.0.1

FROM ubuntu:12.04
MAINTAINER Judd Maltin judd@newgoliath.com
RUN cat /etc/resolv.conf
RUN apt-get update

# install curl and prep scripts to check into Crowbar Admin Server
ADD register-container.sh /root/register-container.sh
ADD register-container.json /root/register-container.json
RUN mkdir -p /var/run/sshd

VOLUME /root/.ssh
RUN apt-get -y install curl vim-tiny openssh-server
RUN chmod 755 /root/register-container.sh


# setup ssh keys for Mr. Root

RUN chown root:root -R /root/.ssh
ADD id_rsa.pub /root/.ssh/authorized_keys
#VOLUME ["/home/judd/crowbar-utils/docker/"]

# install and setup openssh-server
#RUN /usr/bin/sshd -D &

#CMD ["/root/register-container.sh"]
#CMD ["/usr/bin/supervisord"]
