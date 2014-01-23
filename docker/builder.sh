#!/bin/bash
cp /root/.ssh/id_dsa.pub .
docker build -t "newgoliath/crowbar-workload" .

