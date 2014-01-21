#!/bin/bash

cp /root/.ssh/id_rsa.pub .
docker build -rm -t newgoliath/crowbar-workload .

