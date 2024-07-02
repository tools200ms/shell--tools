#!/bin/bash

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe || set -e

# also '--pretend' parameter can be used
[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        RUN="echo " || RUN=


print_helpmsg_and_exit () {
	if [ -n "$1" ] ; then
		echo "error: $1"
		echo ""
	fi

	cat << EOF
$(basename $0) ins|del <interface> --list <path> [--proto tcp|udp] --dst_port
        <port> [--rdst_port <port>] --dst_ip <IP>
	ins - insert rules
	del - delete rules
	--list,-l <file path>   - path to file holding IP/mask list

	--dst_port,-p <port>    - destination port
	--rdst_port,-r <port>   - redirected destination port

	--dst_ip,-i             - source IP

	--proto,-t               - protocol <tcp|udp> - default: tcp

$(basename $0) --help|-h
	print this help

EOF

	[ -n "$1" ] && exit 1 || exit 0
}

IF_ARG=
LIST_ARG=
DST_PORT_ARG=
RDST_PORT_ARG=
DST_IP_ARG=
PROTO_ARG=

EXPECT=

for arg in "$@"
do
	if [ -n "$EXPECT" ]; then
		export "$EXPECT"_ARG="$arg"
		EXPECT=
		continue
	fi

	case $arg in
		ins)
			OP="--insert"
			EXPECT="IF"
		;;
		del)
			OP="--delete"
			EXPECT="IF"
		;;
		--list|-l)
			EXPECT="LIST"
		;;
		--dst_port|-p)
			EXPECT="DST_PORT"
		;;
		--rdst_port|-r)
			EXPECT="RDST_PORT"
		;;
		--dst_ip|-i)
			EXPECT="DST_IP"
		;;
		--proto|-t)
			EXPECT="PROTO"
		;;
		--help|-h)
			print_helpmsg_and_exit
		;;
		*)
			print_helpmsg_and_exit "Unknow parameter: $arg"
		;;
	esac
done

if 	[ -z "$OP" ] || [ -z "$LIST_ARG" ] || \
	[ -z "$DST_PORT_ARG" ] || [ -z "$DST_IP_ARG" ]; then

	print_helpmsg_and_exit "Missing parameter"
fi


if [ -z "$RDST_PORT_ARG" ]; then
	DST="$DST_IP_ARG"
else
	DST="$DST_IP_ARG:$RDST_PORT_ARG"
fi

if [ -z "$PROTO_ARG" ]; then
	PROTO_ARG="tcp"
fi


for PRE_ROUTE_IP in $(cat $LIST_ARG)
do
	$RUN iptables -t nat $OP PREROUTING -i $IF_ARG \
				-s $PRE_ROUTE_IP -p $PROTO_ARG --dport $DST_PORT_ARG \
				-j DNAT --to-destination $DST
done

exit 0
