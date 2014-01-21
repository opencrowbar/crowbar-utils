#!/bin/bash

for x in $(seq 1 1)
do
	#CONTAINER_ID=$(sudo docker run -d ubuntu /bin/sh -c "while true; do echo hello world; sleep 1; done")
	docker run -d ubuntu /bin/sh -c "while true; do echo hello world; sleep 1; done"
done

