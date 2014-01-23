# VERSION 0.0.1

FROM ubuntu:12.04
MAINTAINER Judd Maltin judd@newgoliath.com
RUN apt-get update

# install curl and prep scripts to check into Crowbar Admin Server
ADD register-container.sh /root/register-container.sh
ADD register-container.json /root/register-container.json
RUN apt-get -y install curl vim-tiny
RUN chmod 755 /root/register-container.sh


# setup ssh keys for Mr. Root

#RUN mkdir /root/.ssh
#RUN chown root:root -R /root/.ssh
#ADD id_rsa.pub /root/.ssh/authorized_keys
RUN mkdir /var/run/sshd
VOLUME /root/.ssh
RUN apt-get install -y openssh-server

# install and setup openssh-server
#RUN /usr/bin/sshd -D &

CMD ["/root/register-container.sh"]
