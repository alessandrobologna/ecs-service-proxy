#!/bin/bash
set -e
if [[ "$1" =~ "varnishd" ]]
then
	if [[ -z ${CLUSTER} ]] || [[ -z ${TASKDEF} ]] || [[ -z ${AWS_DEFAULT_REGION} ]]
	then
		echo "Please define CLUSTER, TASKDEF and AWS_DEFAULT_REGION"
		exit 1
	fi
	echo -e "Determining backend configuration for \n  Cluster:\t${CLUSTER}\n  Task:   \t${TASKDEF}"
	exec 6>&1           		 # Link file descriptor #6 with stdout.
	exec > /default.vcl     # stdout replaced with file.
	echo "vcl 4.0;"
	echo "import std;          # load the std library"
	echo "import directors;    # load the directors"
	echo "import bodyaccess;   # load custom vmod"
		
	count=0
	services=$(aws ecs describe-tasks --tasks  $(aws ecs list-tasks  --cluster ${CLUSTER} --query "taskArns" --output text) \
	 --cluster ${CLUSTER} \
	 --query "tasks[?taskDefinitionArn==\`${TASKDEF}\` && lastStatus==\`RUNNING\`].[containerInstanceArn,containers[].networkBindings[].hostPort]" \
	 --output text)  
	 while read line
	 do
	 	if [[ ${line} =~ arn* ]]
	 	then
	 		instanceId=$(aws ecs describe-container-instances --container-instances ${line} \
				--cluster ${CLUSTER} \
				--query "containerInstances[].ec2InstanceId" --output text)
	 		ip=$(aws ec2 describe-instances --instance-id ${instanceId} --query "Reservations[].Instances[].PrivateIpAddress" --output text)
	 		echo -ne "backend server${count} {\n\t.host = \"${ip}\";"
	 	else
	 		echo -e "\n\t.port=\"${line}\";"
		 	if [ -n "${PROBE}" ]
		 	then
			 	echo -e "\t.probe={$(echo ${PROBE} | base64 --decode)}"
		 	fi
		 	echo "}"
		 	count=$(($count+1))
	 	fi
	done <<< "${services}"
	count=$(($count-1))
	echo "#${count} backends"
	echo -e "sub vcl_init {\n\tnew director = directors.round_robin();"
	while [[ $count > -1 ]]
	do 
		echo -e "\tdirector.add_backend(server${count});"
		count=$(($count-1))
	done
	echo "}"
	echo -e "sub vcl_recv {\n\tset req.backend_hint = director.backend();$(echo ${CUSTOM_RECV} | base64 --decode)\n}"
	
	echo "${CUSTOM_VCL}" | base64 --decode
	
	exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
	cat -n /default.vcl
fi

exec $@

