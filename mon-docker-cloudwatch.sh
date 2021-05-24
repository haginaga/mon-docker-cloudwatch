#!/bin/bash

# require:
#   docker, jq, awscli


DEBUG=${DEBUG:-0}

FILTER=${FILTER:-}

INTERVAL=${INTERVAL:-5}


## container api

# Call container API.
#   - method: GET/POST
#   - path: /path/to..
#
function _api() {
	_method=$1
	_path=$2
	curl --unix-socket /var/run/docker.sock -X ${_method} http://localhost${_path} 2>/dev/null
}

# Get container list.
#
function _containers() {
	_api GET "/containers/json" | jq -r '.[] | [.Id,.Names[0],.State] | @csv' | sed -e 's/"//g'
}

# Get container stats.
#   - cid: container id
#
function _stats() {
	_cid=$1
	_api GET "/containers/${_cid}/stats?stream=false" #| jq -r '.[] | [.Id,.Names[0],.State] | @csv' | sed -e 's/"//g'
}

# Parse memory stats.
#   - stats: stats json
#
# return: mem_util(%),used(bytes),available(bytes)
#
# ref: https://docs.docker.com/engine/api/v1.41/#operation/ContainerStats
#
function _parse_mem_stats() {
	_s=$1
	_usage=$( echo ${_s} | jq '.memory_stats.usage' )
	_cache=$( echo ${_s} | jq '.memory_stats.stats.cache' )
	_limit=$( echo ${_s} | jq '.memory_stats.limit' )

	echo "${_usage}|${_cache}|${_limit}" \
	| awk -F'[|]' 'BEGIN{OFS=","} { \
		_used = $1 - $2 ; \
		_util = _used / $3 ; \
		print _util * 100.0, _used, $3 ; \
	}'
}

# Parse cpu stats.
#   - stats: stats json
#
# return: cpu_util(%),user(nsec),system(nsec)
#
# ref: https://docs.docker.com/engine/api/v1.41/#operation/ContainerStats
#
function _parse_cpu_stats() {
	_s=$1
	_cur_usage=$( echo ${_s} | jq '.cpu_stats.cpu_usage.total_usage' )
	_pre_usage=$( echo ${_s} | jq '.precpu_stats.cpu_usage.total_usage' )
	_cur_sys_usage=$( echo ${_s} | jq '.cpu_stats.system_cpu_usage' )
	_pre_sys_usage=$( echo ${_s} | jq '.precpu_stats.system_cpu_usage' )
	_cpus=$( echo ${_s} | jq '.cpu_stats.online_cpus' )

	echo "${_cur_usage}|${_pre_usage}|${_cur_sys_usage}|${_pre_sys_usage}|${_cpus}" \
	| awk -F'[|]' 'BEGIN{OFS=","} { \
		_delta = $1 - $2 ; \
		_sys_delta = $3 - $4 ; \
		_util = ( _delta / _sys_delta ) * $5 ; \
		print _util * 100.0, $1, $3 ; \
	}'
}


## awscli

# Get ec2 instance id
#
function _get_instance_id() {
	curl http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null
}

# AWS: Create metrics.
#   - dim1: dimension1 (instance-id)
#   - dim2: dimension2 (container-name)
#   - name: metrics name
#   - value: metrics value
#   - unit: metrics unit
#
function _create_metrics() {
	_dim1=$1
	_dim2=$2
	_name=$3
	_value=$4
	_unit=$5

	_dim='"Dimensions": ['
	_dim=${_dim}' {"Name":"InstanceId", "Value":"'${_dim1}'"}'
	_dim=${_dim}',{"Name":"ContainerName", "Value":"'${_dim2}'"}'
	_dim=${_dim}' ]'

	_ret='{ "MetricName":"'${_name}'", '${_dim}', "Value":'${_value}', "Unit":"'${_unit}'" }'

	echo ${_ret}
}

function _aws_publish() {
	_ns=$1
	_ins_id=$2
	_con_name=$3

	_mem_util=$4
	_mem_used=$5
	_mem_avail=$6

	_cpu_util=$7
	_cpu_user=$8
	_cpu_sys=$9

	_dt=$( date +"%Y/%m/%d %H:%M:%S" )
	echo "${_dt} Docker - InstanceId:${_ins_id} ContainerName:${_con_name} : MemUtilization:${_mem_util} MemUsed:${_mem_used} MemAvairable:${_mem_avail}"
	echo "${_dt} Docker - InstanceId:${_ins_id} ContainerName:${_con_name} : CPUUtilization:${_cpu_util} CPUUser:${_cpu_user} CPUSystem:${_cpu_sys}"

	_ret='['
	_ret=${_ret}' '$( _create_metrics ${_ins_id} ${_con_name} "ContainerMemoryUtilization" ${_mem_util}  "Percent" )
	_ret=${_ret}','$( _create_metrics ${_ins_id} ${_con_name} "ContainerMemoryUsed"        ${_mem_used}  "Bytes" )
	_ret=${_ret}','$( _create_metrics ${_ins_id} ${_con_name} "ContainerMemoryAvairable"   ${_mem_avail} "Bytes" )
	_ret=${_ret}','$( _create_metrics ${_ins_id} ${_con_name} "ContainerCPUUtilization"    ${_cpu_util}  "Percent" )
	_ret=${_ret}','$( _create_metrics ${_ins_id} ${_con_name} "ContainerCPUUser"           ${_cpu_user}  "Microseconds" )
	_ret=${_ret}','$( _create_metrics ${_ins_id} ${_con_name} "ContainerCPUSystem"         ${_cpu_sys}   "Microseconds" )
	_ret=${_ret}' ]'

	echo ${_ret} > /tmp/__mon.json

	if test ${DEBUG} -ne 0 ; then
		cat /tmp/__mon.json | jq .
	fi

	aws cloudwatch put-metric-data --namespace ${_ns} --metric-data file:///tmp/__mon.json
}


## main

function run() {
	_insid=$1
	_cid=$2
	_name=$3

	_s=$( _stats ${_cid} )

	if test ${DEBUG} -ne 0 ; then
		echo ${_name} / ${_cid}
	fi
	_mem=$( _parse_mem_stats "${_s}" )
	_cpu=$( _parse_cpu_stats "${_s}" )

	_aws_publish "CustomMetrics" ${_insid} ${_name} \
		$( echo ${_mem} | cut -d, -f1 ) \
		$( echo ${_mem} | cut -d, -f2 ) \
		$( echo ${_mem} | cut -d, -f3 ) \
		$( echo ${_cpu} | cut -d, -f1 ) \
		$( echo ${_cpu} | cut -d, -f2 ) \
		$( echo ${_cpu} | cut -d, -f3 )
}

_instance_id=$( _get_instance_id )

_nn=$( echo ${FILTER} | sed -e 's/,/\\|/g' )

while :
do
	for c in $( _containers ) ; do
		_cid=$(  echo $c | cut -d"," -f1 )
		_name=$( echo $c | cut -d"," -f2 | sed -e 's,^/,,' )

		if test "${_nn}" != "" ; then
			echo ${_name} | grep -e ${_nn} 2>&1 > /dev/null
			if test $? != 0 ; then
				continue
			fi
		fi

		run ${_instance_id} ${_cid} ${_name}
	done

	if test ${INTERVAL} == 0 ; then
		break;
	fi
	sleep ${INTERVAL}
done


# EOF
