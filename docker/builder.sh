#!/bin/bash
cp /root/.ssh/id_rsa.pub .
docker build -t "newgoliath/crowbar-workload" .

