#!/bin/bash

RWD=$(dirname "$(realpath "$0")")

. ${RWD}/global_env

run_if_exist() {
	[[ $(type -t $1) == function ]] && $1
}

reload_env() {
	unset -f pre_start
	unset -f post_start

	unset -f pre_stop
	unset -f post_stop

	unset DOCKER_RUN_ARGS
	unset DOCKER_IMG
	unset SERVICE_SHELL
	unset COMPOSE
	unset SUBDOMAIN

	. ${RWD}/${DOCKER_SERVICE}/env
	if [ -n "${SUBDOMAIN}" ]; then
		export HOST_NAME=${SUBDOMAIN}.${TLD}
	else
		export HOST_NAME=www.${TLD}
	fi
}

start() {
	run_if_exist pre_start
	if [ "${COMPOSE}" == 1 ]; then
		docker-compose -f ${RWD}/${DOCKER_SERVICE}/docker-compose.yml up -d
	else
		docker run -it -d --restart on-failure \
			--name ${DOCKER_SERVICE} \
			${DOCKER_RUN_ARGS} \
			${DOCKER_IMG}
	fi
	run_if_exist post_start
}

stop() {
	run_if_exist pre_stop
	if [ "${COMPOSE}" == 1 ]; then
		docker-compose -f ${RWD}/${DOCKER_SERVICE}/docker-compose.yml down
	else
		docker kill ${DOCKER_SERVICE}
		docker rm ${DOCKER_SERVICE}
	fi
	run_if_exist post_stop
}

restart() {
	stop
	start
}

status() {
	if [ "$(docker container inspect -f '{{.State.Status}}' $DOCKER_SERVICE)" == "running" ]; then
		RUNNING=1
		echo "RUNNING"
	else
		RUNNING=0
		echo "DOWN"
	fi
	#echo $(docker container inspect -f '{{.State.Status}}' $DOCKER_SERVICE)
	return ${RUNNING}
}

log() {
	docker logs --follow $DOCKER_SERVICE
}

help() {
	echo "$0 init|start|stop|restart|enter|status|log [services]"
}

OP=""
DOCKER_SERVICES=""

for parameter in "$@"; do
case $parameter in
	start|stop|restart|init|enter|status|log)
		OP=${parameter}
		;;
	all)
		DOCKER_SERVICES="nginx openvpn wetty mysql wordpress"
		;;
	*)
		if test -d ${RWD}/${parameter}; then
			DOCKER_SERVICES="${DOCKER_SERVICES} $parameter"
		else
			echo "invalid input: $parameter"
			help
			exit
		fi
		;;
esac
done

if test -z "${OP}" || test -z "${DOCKER_SERVICES}"; then
	echo "missing operation or service name"
	help
	exit
fi
DOCKER_SERVICE_LIST=(${DOCKER_SERVICES})

for DOCKER_SERVICE in "${DOCKER_SERVICE_LIST[@]}"; do
echo "${OP} docker serivce ${DOCKER_SERVICE}..."
export DOCKER_SERVICE # so it is accessible by docker-compose
reload_env
case ${OP} in
	start|stop|restart|status|init|log)
		${OP}
		;;
	enter)
		test -z ${SERVICE_SHELL} || docker exec -it ${DOCKER_SERVICE} ${SERVICE_SHELL}
		;;
	*)
		help
		;;
esac
echo ""
done
