# VERSION 0.0.1

FROM ubuntu:12.04
MAINTAINER Judd Maltin judd@newgoliath.com

# setup ssh keys for Mr. Root

RUN mkdir /root/.ssh
RUN chown root:root -R /root/.ssh
ADD id_rsa.pub /root/.ssh/authorized_keys

# install and setup openssh-server
RUN apt-get update
RUN apt-get install openssh-server
RUN mkdir /var/run/sshd
RUN /usr/bin/sshd -D &

# check into Crowbar Admin Server
RUN apt-get install curl
#ADD crowbar-utils/docker/register_container.sh /root/register_container.sh
#ADD crowbar-utils/docker/node_samples.json /root/node_samples.json
RUN chmod 755 /root/register_container.sh
CMD /root/register_container.sh



