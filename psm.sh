#!/bin/bash

# PSM_LOG_LEVEL=${PSM_LOG_LEVEL:-3}
LOG_LEVELS='{
	"0": "FATAL",
	"1": "ERROR",
	"2": "WARN",
	"3": "INFO",
	"4": "DEBUG",
	"5": "TRACE"
}'

function build_info {
	[[ -z $GIT_TAG ]] && [[ -z $GIT_BRANCH ]] && GIT_TAG="edge"                    #               edge release

	[[ -n ${GIT_TAG} ]] && send_log 3 "Build version: ${GIT_TAG:-unknown}"         # GIT_TAG       populated on release only
	[[ -n ${GIT_BRANCH} ]] && send_log 3 "Build branch: ${GIT_BRANCH:-unknown}"    # GIT_BRANCH    populated on pr only
	[[ -n ${GIT_COMMIT} ]] && send_log 3 "Build commit: ${GIT_COMMIT:-unknown}"    # GIT_COMMIT    always populated
}

function load_configuration {
	GRPCURL=grpcurl
	DELAY=60

	CURRENT_STATE=$(jq -c '.' /psm/config.json)
	validate_json "$CURRENT_STATE" || { send_log 0 "FATAL" "json validation failed. EXITING..."; exit 1; }

	NODE_PROVING_READY=false	# helper variable to limit excessive node queries

	NODE=$(echo "$CURRENT_STATE" | jq -r '.node["name"]')
	NODE_IP_ADDRESS=$(echo "$CURRENT_STATE" | jq -r '.node.endpoint["ip_address"]')
	NODE_LISTENER_PORT=$(echo "$CURRENT_STATE" | jq -r '.node.endpoint["node_listener_port"]')
	NODE_SERVICE="${NODE_IP_ADDRESS}:${NODE_LISTENER_PORT}"

	POST_IP_ADDRESS=$(echo "$CURRENT_STATE" | jq -r '.smesher.endpoint["ip_address"] // .node.endpoint["ip_address"]')
	POST_LISTENER_PORT=$(echo "$CURRENT_STATE" | jq -r '.smesher.endpoint["post_listener_port"] // .node.endpoint["post_listener_port"]')
	POST_SERVICE="${POST_IP_ADDRESS}:${POST_LISTENER_PORT}"

	SMESHER_IP_ADDRESS=$(echo "$CURRENT_STATE" | jq -r '.smesher.endpoint["ip_address"] // .node.endpoint["ip_address"]')
	SMESHER_LISTENER_PORT=$(echo "$CURRENT_STATE" | jq -r '.smesher.endpoint["node_listener_port"] // .node.endpoint["node_listener_port"]')
	SMESHER_SERVICE="${SMESHER_IP_ADDRESS}:${SMESHER_LISTENER_PORT}"

	POST_SERVICE_PARALLEL=$(echo "$CURRENT_STATE" | jq -r '.node.post["service_parallel"] // 1')    # default to 1 service in p1

	send_log 4 "NODE_SERVICE: ${NODE_SERVICE}"
	send_log 4 "POST_SERVICE: ${POST_SERVICE}"
	send_log 4 "SMESHER_SERVICE: ${SMESHER_SERVICE}"
}

function validate_json {
    local JSON=$1

	#### validate json structure

	CRITERIA=".network exists"
	jq '.network' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".network has required properties"
	jq -e '.network | has("main", "state")' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	# test for node array
	# test node.poet
	# test node.poet.state
	# add test for .network.main["layer_duration"] can fail convert_to_layers

	CRITERIA=".services exists"
    jq '.services' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".services is a non-empty array"
	jq -e '.services | type == "array" and length > 0' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".services has required properties (for each child object)"
	jq -e 'all(.services[]; has("name") and has("endpoint") and has("post") and has("state"))' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }


	#### validate json key content

	CRITERIA=".name is a non-empty string"
	jq -e 'all(.services[].name; type == "string" and length > 0)' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	# CRITERIA=".endpoint.ip_address is a valid IP address"
	# jq -e 'all(.services[].endpoint.ip_address; test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<< "$JSON" > /dev/null \
	# 	&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
	#	|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".endpoint.metrics is a url starting with http:// or https://"
	jq -e 'all(.services[].endpoint.metrics; startswith("http://") or startswith("https://"))' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".state.online is a boolean"
	jq -e 'all(.services[].state.online; type == "boolean")' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	# CRITERIA=".post.id is a 43-char long (+ 1-char padding) base64 encoded string"
	# jq -e 'all(.services[].post.id; test("^[A-Za-z0-9+/]{43}=$"))' <<< "$JSON" > /dev/null \
	# 	&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
	# 	|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".post.numunits is a non-negative integer"
	jq -e 'all(.services[].post.numunits; type == "number" and . >= 0 and (floor - .) == 0)' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".state.phase is a string (can be empty)"
	jq -e 'all(.services[].state.phase; type == "string")' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".state.nonce is a string (can be empty)"
	jq -e 'all(.services[].state.nonce; type == "string")' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

	CRITERIA=".state.progress is a non-negative integer"
	jq -e 'all(.services[].state.progress; type == "number" and . >= 0 and (floor - .) == 0)' <<< "$JSON" > /dev/null \
		&& { send_log 4 "PASS: ${CRITERIA}"; true; } \
		|| { send_log 1 "FAIL: ${CRITERIA}"; return 1; }

    send_log 4 "json is valid"
    return 0
}

function convert_to_seconds {
    local INPUT=$1
    local LENGTH=${#INPUT}
    local NUMBER=${INPUT%?}
    local UNIT=${INPUT:$LENGTH-1:1}

    case $UNIT in
        "s")
            echo $NUMBER
            ;;
        "m")
            echo $(($NUMBER * 60))
            ;;
        "h")
            echo $(($NUMBER * 3600))
            ;;
        "d")
            echo $(($NUMBER * 86400))
            ;;
        *)
            echo "Invalid unit. Please use s for seconds, m for minutes, h for hours, or d for days."
            ;;
    esac
}

function convert_to_layers {
	local LAYER_DURATION=$(convert_to_seconds $(echo "$CURRENT_STATE" | jq -r '.network.main.layer_duration'))

    local INPUT=$1
    local SECONDS=$(convert_to_seconds $INPUT)
    local LAYERS=$(($SECONDS / $LAYER_DURATION))

    echo $LAYERS
}

function convert_layer_to_datetime {
    local LAYERS=$1
	local LAYER_DURATION=$(convert_to_seconds $(echo "$CURRENT_STATE" | jq -r '.network.main.layer_duration'))

    local TOTAL_SECONDS=$((LAYERS * LAYER_DURATION))    # convert layers to seconds
    local CURRENT_TIME=$(date +%s)                      # get the current time in unix timestamp
    local TARGET_TIME=$((CURRENT_TIME + TOTAL_SECONDS))

    date -d "@$TARGET_TIME" "+%d-%b-%Y %H:%M %Z"        # format output datetime
}

function convert_layer_to_countdown {
    local LAYERS=$1
	local LAYER_DURATION=$(convert_to_seconds $(echo "$CURRENT_STATE" | jq -r '.network.main.layer_duration'))

	local TOTAL_SECONDS=$((LAYERS * LAYER_DURATION))    # convert layers to seconds
	local DAYS=$((TOTAL_SECONDS / 86400))
	local HOURS=$(( (TOTAL_SECONDS % 86400) / 3600 ))
	local MINUTES=$(( (TOTAL_SECONDS % 3600) / 60 ))

    if (( DAYS == 0 && HOURS == 0 && MINUTES == 0 )); then
        echo ""
    elif (( DAYS == 0 && HOURS == 0 )); then
        printf "%02dm\n" $MINUTES
    elif (( DAYS == 0 )); then
        printf "%02dh %02dm\n" $HOURS $MINUTES
    else
        printf "%dd %02dh %02dm\n" $DAYS $HOURS $MINUTES
    fi
}

function send_log {
	local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
	local FUNCTION_NAME=${FUNCNAME[1]}
	
	local MESSAGE=$2
	local LOG_LEVEL_ID=$1
	local LOG_LEVEL=$(echo $LOG_LEVELS | jq -r ".[\"$LOG_LEVEL_ID\"]")	

	if (( $LOG_LEVEL_ID <= $PSM_LOG_LEVEL )); then
		printf "%-25s %-10s %-30s %s\n" "${TIMESTAMP}" "${LOG_LEVEL}" "[${FUNCTION_NAME}]" "${MESSAGE}"
	fi
}

function get_online_state {
    local NAME=$1
    local IP=$2
    local TYPE=$3

    ping -c 1 $IP > /dev/null 2>&1 &
    local PID=$!
    PIDS+=("$PID:$NAME:$IP:$TYPE")
}

function set_online_state {
    PIDS=()		# reset array

    # check primary node
    local NODE_NAME=$(echo "${CURRENT_STATE}" | jq -r '.node.name')
    local NODE_IP=$(echo "${CURRENT_STATE}" | jq -r '.node.endpoint.ip_address')
    get_online_state $NODE_NAME $NODE_IP "NODE"

    # check services
    while IFS= read -r SERVICE; do
        local SERVICE_NAME=$(echo "$SERVICE" | jq -r '.name')
        local SERVICE_IP=$(echo "$SERVICE" | jq -r '.endpoint.ip_address')
        get_online_state $SERVICE_NAME $SERVICE_IP "SERVICE"
    done < <(echo "${CURRENT_STATE}" | jq -c '.services[]')

    # wait for all pings to complete and update the CURRENT_STATE
    for pid_info in "${PIDS[@]}"; do
        local PID=$(echo "$pid_info" | cut -d: -f1)
        local NAME=$(echo "$pid_info" | cut -d: -f2)
        local IP=$(echo "$pid_info" | cut -d: -f3)
        local TYPE=$(echo "$pid_info" | cut -d: -f4)
        local SERVICE_ONLINE=false

        wait $PID && SERVICE_ONLINE=true
        send_log 4 "${TYPE} ${NAME} ${IP} is $( $SERVICE_ONLINE && echo "online" || echo "offline" )"

		if [ "$TYPE" == "NODE" ]; then
			CURRENT_STATE=$(echo "${CURRENT_STATE}" | jq \
				--arg online "$SERVICE_ONLINE" \
				'.node.state.online = $online | 
				if $online == "false" then .node.state.is_synced = false else . end'
			)
		else
			CURRENT_STATE=$(echo "${CURRENT_STATE}" | jq \
				--arg name "$NAME" \
				--arg online "$SERVICE_ONLINE" \
				'.services |= map(
					if .name == $name then .state.online = $online else . end
				)'
			)
		fi
    done
}

function set_poet_state {
	local PHASE_SHIFT=$(echo "$CURRENT_STATE" | jq -r '.node.poet.phase_shift')
	local CYCLE_GAP=$(echo "$CURRENT_STATE" | jq -r '.node.poet.cycle_gap')	
	local GRACE_PERIOD=$(echo "$CURRENT_STATE" | jq -r '.node.poet.grace_period')
	local LAYERS_PER_EPOCH=$(echo "$CURRENT_STATE" | jq -r '.network.main.layers_per_epoch')
	local CURRENT_LAYER=$(echo "$CURRENT_STATE" | jq -r '.network.state.layer')
	local CURRENT_EPOCH=$(echo "$CURRENT_STATE" | jq -r '.network.state.epoch')

	local EPOCH_OPENED_LAYER=$(($LAYERS_PER_EPOCH * $CURRENT_EPOCH))
	local EPOCH_CLOSED_LAYER=$((($LAYERS_PER_EPOCH * $CURRENT_EPOCH) + $LAYERS_PER_EPOCH - 1))
	local EPOCH_OPENED_COUNTDOWN_LAYER=$(($EPOCH_OPENED_LAYER - $CURRENT_LAYER))
	local EPOCH_CLOSED_COUNTDOWN_LAYER=$(($EPOCH_CLOSED_LAYER - $CURRENT_LAYER))	
	local CYCLE_GAP_OPENED_LAYER=$(($EPOCH_OPENED_LAYER + ($(convert_to_layers $PHASE_SHIFT)-$(convert_to_layers $CYCLE_GAP) ) ))
	local CYCLE_GAP_CLOSED_LAYER=$(($CYCLE_GAP_OPENED_LAYER + $(convert_to_layers $CYCLE_GAP)))
	local CYCLE_GAP_OPENED_COUNTDOWN_LAYER=$(($CYCLE_GAP_OPENED_LAYER - $CURRENT_LAYER))
	local CYCLE_GAP_CLOSED_COUNTDOWN_LAYER=$(($CYCLE_GAP_CLOSED_LAYER - $CURRENT_LAYER))
	local REGISTRATION_OPENED_LAYER=$(($CYCLE_GAP_CLOSED_LAYER - $(convert_to_layers $GRACE_PERIOD)))
	local REGISTRATION_OPENED_COUNTDOWN_LAYER=$(($REGISTRATION_OPENED_LAYER - $CURRENT_LAYER))	

	local EPOCH_PHASE=$( 
		if   (( CURRENT_LAYER < CYCLE_GAP_OPENED_LAYER    )); then echo "EPOCH_OPENING"
		elif (( CURRENT_LAYER < REGISTRATION_OPENED_LAYER )); then echo "CYCLE_GAP"
		elif (( CURRENT_LAYER < CYCLE_GAP_CLOSED_LAYER    )); then echo "CYCLE_GAP_REGISTRATION"
		elif (( CURRENT_LAYER < EPOCH_CLOSED_LAYER        )); then echo "EPOCH_CLOSING"
		else echo "UNKNOWN_PHASE"
		fi
	)

	send_log 4 "epoch ${CURRENT_EPOCH} open from: ${EPOCH_OPENED_LAYER}(${EPOCH_OPENED_COUNTDOWN_LAYER}) to ${EPOCH_CLOSED_LAYER}(${EPOCH_CLOSED_COUNTDOWN_LAYER})"	
	send_log 4 "epoch ${CURRENT_EPOCH} cycle gap open from: ${CYCLE_GAP_OPENED_LAYER}(${CYCLE_GAP_OPENED_COUNTDOWN_LAYER}) to ${CYCLE_GAP_CLOSED_LAYER}(${CYCLE_GAP_CLOSED_COUNTDOWN_LAYER})"
	send_log 4 "epoch ${CURRENT_EPOCH} cycle gap registration open from: ${REGISTRATION_OPENED_LAYER}(${REGISTRATION_OPENED_COUNTDOWN_LAYER}) to ${CYCLE_GAP_CLOSED_LAYER}(${CYCLE_GAP_CLOSED_COUNTDOWN_LAYER})"
	send_log 4 "epoch ${CURRENT_EPOCH} current phase: ${EPOCH_PHASE}"

	CURRENT_STATE=$(echo "$CURRENT_STATE" | jq "
		.network.state.epoch_opened_layer = ${EPOCH_OPENED_LAYER} |
		.network.state.epoch_closed_layer = ${EPOCH_CLOSED_LAYER} |
		.network.state.epoch_opened_countdown_layer = ${EPOCH_OPENED_COUNTDOWN_LAYER} |
		.network.state.epoch_closed_countdown_layer = ${EPOCH_CLOSED_COUNTDOWN_LAYER} |		
		.node.state.phase = \"${EPOCH_PHASE}\" |
		.node.state.cycle_gap_opened_layer = ${CYCLE_GAP_OPENED_LAYER} |
		.node.state.cycle_gap_closed_layer = ${CYCLE_GAP_CLOSED_LAYER} |
		.node.state.cycle_gap_opened_countdown_layer = ${CYCLE_GAP_OPENED_COUNTDOWN_LAYER} |
		.node.state.cycle_gap_closed_countdown_layer = ${CYCLE_GAP_CLOSED_COUNTDOWN_LAYER} |
		.node.state.registration_opened_layer = ${REGISTRATION_OPENED_LAYER} |
		.node.state.registration_opened_countdown_layer = ${REGISTRATION_OPENED_COUNTDOWN_LAYER}
	")
}

function get_node_state {
    local PAYLOAD=$($GRPCURL -plaintext $NODE_SERVICE spacemesh.v1.NodeService.Status 2>/dev/null)
    
	# if grpc server is not ready and gives other output, treat as sync status = false
	[[ $(echo "$PAYLOAD" | jq -r '.status.isSynced') == "true" ]] && echo true || echo false
}

function set_network_state {
	local PAYLOAD=$($GRPCURL -plaintext $NODE_SERVICE spacemesh.v1.MeshService.CurrentLayer)
	local LAYERS_PER_EPOCH=$(echo "$CURRENT_STATE" | jq -r '.network.main.layers_per_epoch')

	local CURRENT_LAYER=$(echo "$PAYLOAD" | jq -r '.layernum.number')
	local CURRENT_EPOCH=$(( $CURRENT_LAYER / $LAYERS_PER_EPOCH ))

	CURRENT_STATE=$(jq ".network.state.epoch = $CURRENT_EPOCH | \
						.network.state.layer = $CURRENT_LAYER" <<< "$CURRENT_STATE")
	
	send_log 4 "epoch ${CURRENT_EPOCH} layer ${CURRENT_LAYER}"
}

function set_node_sync_state {
	local IS_SYNCED=$(get_node_state)

	CURRENT_STATE=$(jq ".node.state.is_synced = $IS_SYNCED" <<< "$CURRENT_STATE")	

	send_log 4 "NODE ${NODE_IP_ADDRESS} $( [ "$IS_SYNCED" = "true" ] && echo "is synced" || echo "is NOT synced" )"
}

function set_proving_state {
	local SERVICE=$1
	local SERVICE_NAME=$(echo "$SERVICE" | jq -r '.name')
	local SERVICE_ONLINE=$(echo "$SERVICE" | jq -r '.state.online')
	local SERVICE_METRICS=$(echo "$SERVICE" | jq -r '.endpoint.metrics')
	local SERVICE_NUMUNITS=$(echo "$SERVICE" | jq -r '.post.numunits')
	
	local PROVING_PHASE="OFFLINE"	# OFFLINE, READY, PROVING_POW, PROVING_DISK, WAITING, DONE
	local PROVING_NONCE=""
	local PROVING_PROGRESS=0
	local NONCE_SEARCH_START=0
	local NONCE_SEARCH_END=0
	local NONCE_SEARCH_POSITION=0
	local NOW=$(date +%s)
	local NUMUNITS_BYTES=$(($SERVICE_NUMUNITS * 64 * 1024 * 1024 * 1024))	# 1 NUMUNITS(SU) = 64GiB

	if $SERVICE_ONLINE
	then
		local PAYLOAD
		while true; do
			if PAYLOAD=$(curl -s --fail ${SERVICE_METRICS}); then
				break
			else
				send_log 2 "Failed to fetch metrics from ${SERVICE_METRICS}, retrying in 5 seconds..."
				sleep 5
			fi
		done
	
		case $PAYLOAD in
			'"Idle"')
				if cycle_gap_is_open
				then
					PROVING_PHASE="DONE"
					PROVING_PROGRESS=100.00
				else
					PROVING_PHASE="READY"
					PROVING_PROGRESS=0
				fi
			;;
			'"DoneProving"')
				PROVING_PHASE="WAITING"
				PROVING_PROGRESS=100.00	
			;;
			*)	
				NONCE_SEARCH_START=$(echo $PAYLOAD | jq '.Proving.nonces.start')
				NONCE_SEARCH_END=$(echo $PAYLOAD | jq '.Proving.nonces.end')
				NONCE_SEARCH_POSITION=$(echo $PAYLOAD | jq '.Proving.position')

				PROVING_PHASE=$(if (( NONCE_SEARCH_POSITION > 0 )); then echo "PROVING_DISK"; else echo "PROVING_POW"; fi)
				PROVING_NONCE="${NONCE_SEARCH_START}..${NONCE_SEARCH_END}"				
				PROVING_PROGRESS=$(echo "scale=2; ($NONCE_SEARCH_POSITION * 100 / $NUMUNITS_BYTES )" | bc)
			;;
		esac
	fi

	local TIMESTAMP_START_POW=$(echo "$SERVICE" | jq -r '.state.runtime.timestamp_start_pow')
	local TIMESTAMP_START_DISK=$(echo "$SERVICE" | jq -r '.state.runtime.timestamp_start_disk')
	local TIMESTAMP_FINISH=$(echo "$SERVICE" | jq -r '.state.runtime.timestamp_finish')
	local RUNTIME_POW=$(echo "$SERVICE" | jq -r '.state.runtime.runtime_pow')
	local RUNTIME_DISK=$(echo "$SERVICE" | jq -r '.state.runtime.runtime_disk')
	local RUNTIME_OVERALL=$(echo "$SERVICE" | jq -r '.state.runtime.runtime_overall')
	local READ_RATE_MiB=$(echo "$SERVICE" | jq -r '.state.runtime.read_rate_mib')

	case $PROVING_PHASE in
		PROVING_POW)
			if [[ $TIMESTAMP_START_POW -eq 0 ]]; then TIMESTAMP_START_POW=$NOW; fi
			TIMESTAMP_START_DISK=0
			TIMESTAMP_FINISH=0

			RUNTIME_POW=$((($NOW - $TIMESTAMP_START_POW) / 60))	
			RUNTIME_DISK=0
			RUNTIME_OVERALL=$RUNTIME_POW

			READ_RATE_MiB=0
		;;
		PROVING_DISK)
			if [[ $TIMESTAMP_START_POW -eq 0 ]]; then TIMESTAMP_START_POW=$NOW; fi
			if [[ $TIMESTAMP_START_DISK -eq 0 ]]; then TIMESTAMP_START_DISK=$NOW; fi
			TIMESTAMP_FINISH=0

			RUNTIME_POW=$((($TIMESTAMP_START_DISK - $TIMESTAMP_START_POW) / 60))
			RUNTIME_DISK=$((($NOW - $TIMESTAMP_START_DISK) / 60))
			RUNTIME_OVERALL=$(($RUNTIME_POW + $RUNTIME_DISK))

			if [ $RUNTIME_DISK -eq 0 ]; then
				READ_RATE_MiB=0
			else
				READ_RATE_MiB=$(echo "scale=2; ($NUMUNITS_BYTES * ($PROVING_PROGRESS / 100)) / ($RUNTIME_DISK * 60) / 1024 / 1024" | bc)
			fi
		;;
		WAITING | DONE)
			if [[ $TIMESTAMP_START_POW -eq 0 ]]; then TIMESTAMP_START_POW=$NOW; fi
			if [[ $TIMESTAMP_START_DISK -eq 0 ]]; then TIMESTAMP_START_DISK=$NOW; fi
			if [[ $TIMESTAMP_FINISH -eq 0 ]]; then TIMESTAMP_FINISH=$NOW; fi

			RUNTIME_POW=$((($TIMESTAMP_START_DISK - $TIMESTAMP_START_POW) / 60))
			RUNTIME_DISK=$((($TIMESTAMP_FINISH - $TIMESTAMP_START_DISK) / 60))
			RUNTIME_OVERALL=$(($RUNTIME_POW + $RUNTIME_DISK))

			READ_RATE_MiB=$( echo "scale=2; ($NUMUNITS_BYTES * ($PROVING_PROGRESS / 100)) / (($RUNTIME_DISK * 60) + 1 * 1024 * 1024)" | bc )
		;;
		*)	
			# OFFLINE or READY
			TIMESTAMP_START_POW=0
			TIMESTAMP_START_DISK=0
			TIMESTAMP_FINISH=0
			RUNTIME_POW=0
			RUNTIME_DISK=0
			RUNTIME_OVERALL=0
			READ_RATE_MiB=0
		;;
	esac

	CURRENT_STATE=$(echo "$CURRENT_STATE" | jq \
		--arg name "$SERVICE_NAME" \
		--arg online "$SERVICE_ONLINE" \
		--arg phase "$PROVING_PHASE" \
		--arg progress "$PROVING_PROGRESS" \
		--arg nonce "$PROVING_NONCE" \
		--argjson tspow "$TIMESTAMP_START_POW" \
		--argjson tsdisk "$TIMESTAMP_START_DISK" \
		--argjson tsfinish "$TIMESTAMP_FINISH" \
		--argjson rpow "$RUNTIME_POW" \
		--argjson rdisk "$RUNTIME_DISK" \
		--argjson roverall "$RUNTIME_OVERALL" \
		--argjson readrate "$READ_RATE_MiB" \
		'.services |= map(
			if .name == $name then (
				.state.online = $online |
				.state.phase = $phase |
				.state.progress = $progress |
				.state.nonce = $nonce |
				.state.runtime.timestamp_start_pow = $tspow |
				.state.runtime.timestamp_start_disk = $tsdisk |
				.state.runtime.timestamp_finish = $tsfinish |
				.state.runtime.read_rate_mib = $readrate |
				.state.runtime.runtime_pow = $rpow |
				.state.runtime.runtime_disk = $rdisk |
				.state.runtime.runtime_overall = $roverall
			) else . 
		end)'
	)

	local SEND_LOG_MESSAGE="${SERVICE_NAME} phase: ${PROVING_PHASE}"
	[[ -n ${PROVING_NONCE} ]] && SEND_LOG_MESSAGE+="  progress: ${PROVING_PROGRESS} % (${PROVING_NONCE})  speed: ${READ_RATE_MiB} MiB/s"
	[[ ${PROVING_PHASE} != "READY" && ${PROVING_PHASE} != "OFFLINE" ]] && SEND_LOG_MESSAGE+="  runtime: ${RUNTIME_OVERALL}m (pow=${RUNTIME_POW}m disk=${RUNTIME_DISK}m)"
	send_log 4 "$SEND_LOG_MESSAGE"

}

function set_services_state {
	
	local SERVICES=$(echo "$CURRENT_STATE" | jq -c '.services[]')

	for SERVICE in $SERVICES
	do
		set_proving_state "${SERVICE}"
	done
}

function set_current_state {	
	send_log 3 "loading network state..."	
	set_online_state

	local NODE_ENDPOINT_ONLINE=$(echo "$CURRENT_STATE" | jq -r '.node.state.online')
	local NODE_STATE_IS_SYNCED=false

	if $NODE_ENDPOINT_ONLINE
	then
		set_node_sync_state
		local NODE_STATE_IS_SYNCED=$(echo "$CURRENT_STATE" | jq -r '.node.state.is_synced')
	fi

	if $NODE_STATE_IS_SYNCED
	then
		set_network_state

		send_log 3 "loading poet state..."
		set_poet_state
	else
		send_log 2 "node offline or not synced - network and poet state not updated"
	fi

	send_log 3 "loading post-services state..."
	set_services_state
}

function cycle_gap_is_open {
	local NODE_ENDPOINT_ONLINE=$(echo "$CURRENT_STATE" | jq -r '.node.state.online')
	local EPOCH_PHASE=$(echo "$CURRENT_STATE" | jq -r '.node.state.phase')

	# if cycle gap is open, but poet proof is late, then consider cycle gap closed
	# this prevents services starting in an indeterminate proving state
	if [[ "${EPOCH_PHASE}" == CYCLE_GAP* ]]
	then
		# if cycle gap open layer has passed, speed up loop iternation
		# ideally this should be done on main loop with other DELAY setting
		# may happen if splitting function later between cg layer opening, and poet proof fetched events
		DELAY=60

		# do not check if node has received poet proof, if already confirmed for this cycle gap
		# this creates an allowance for node to go offline and not impact starting services
		if [[ "${NODE_PROVING_READY}" == false ]]
		then
			local PAYLOAD=$($GRPCURL -plaintext $POST_SERVICE spacemesh.v1.PostInfoService.PostStates 2>/dev/null)
			NODE_PROVING_READY=$(echo "$PAYLOAD" | grep -q "PROVING" && echo true || echo false)
		fi

		if [[ "${NODE_PROVING_READY}" == true ]]
		then
			# cycle_gap_is_open=true
			return 0
		fi
	fi

	# false if not in cycle gap
	NODE_PROVING_READY=false

	# cycle_gap_is_open=false
	return 1
}

function any_services_proving_pow {	
	local SERVICES=$(echo $CURRENT_STATE | jq '[.services[] | select(.state.phase=="PROVING_POW")]')
    local SERVICES_COUNT=$(jq 'length' <<< "$SERVICES")	

	send_log 4 "SERVICES_COUNT: ${SERVICES_COUNT}"
    
    if (( ${SERVICES_COUNT} < ${POST_SERVICE_PARALLEL} ))
	then
		send_log 4 "false: no services (or under threshold) are in PROVING_POW phase"
		return 1
	else
		send_log 4 "true: one or more services are in PROVING_POW phase"
		return 0
	fi
}

function all_services_online {
	local SERVICES=$(echo $CURRENT_STATE | jq '[.services[] | select(.state.phase=="OFFLINE")]')

	if [ "$SERVICES" == "[]" ]
	then
		send_log 4 "true: all services are ONLINE (NOT OFFLINE)"
		return 0
    else
		send_log 4 "false: one or more services are OFFLINE"
		return 1
    fi
}

function any_services_not_offline {
	local SERVICES=$(echo $CURRENT_STATE | jq '[.services[] | select(.state.phase!="OFFLINE")]')

	if [ "$SERVICES" == "[]" ]
	then
		send_log 4 "false: no services are ONLINE (NOT OFFLINE)"
		return 1
    else
		send_log 4 "true: one or more services are ONLINE (NOT OFFLINE)"
		return 0
    fi
}

function all_services_done {
	local SERVICES=$(echo $CURRENT_STATE | jq '[.services[] | select(.state.phase!="DONE")]')

	if [ "$SERVICES" == "[]" ]
	then
		send_log 4 "true: all services are DONE"
		return 0
    else
		send_log 4 "false: one or more services are not DONE"
		return 1
    fi
}

function start_next_service {
	local SERVICE=$(echo $CURRENT_STATE | jq 'first(.services[] | select(.state.phase=="OFFLINE"))')
	local SERVICE_NAME=$(echo $SERVICE | jq -r '.name')

	docker start $SERVICE_NAME > /dev/null 2>&1
	send_log 3 "starting $SERVICE_NAME"

	# zero out runtime state metrics
	CURRENT_STATE=$(echo "$CURRENT_STATE" | jq \
		--arg name "$SERVICE_NAME" \
		'.services |= map(
			if .name == $name then (
				.state.runtime.timestamp_start_pow = 0 |
				.state.runtime.timestamp_start_disk = 0 |
				.state.runtime.timestamp_finish = 0 |
				.state.runtime.runtime_pow = 0 |
				.state.runtime.runtime_disk = 0 |
				.state.runtime.runtime_overall = 0
			) else . 
		end)'
	)
}

function stop_idle_services {
	local SERVICES=$(echo $CURRENT_STATE | jq -c '.services[] | select(.state.phase=="DONE" or .state.phase=="READY")')

	for SERVICE in $SERVICES; do
		local SERVICE_NAME=$(echo $SERVICE | jq -r '.name')

		docker stop $SERVICE_NAME > /dev/null 2>&1
		send_log 3 "stopping $SERVICE_NAME"
	done
}

function export_state {
	echo $CURRENT_STATE > /psm/state.json
}

function show_metrics {
	node_metrics
	layer_metrics
	postservice_metrics
}

function node_metrics {
	local NODE_EPOCH=$(echo "$CURRENT_STATE" | jq -r '.network.state.epoch')
	local NODE_LAYER=$(echo "$CURRENT_STATE" | jq -r '.network.state.layer')
	local NODE_PHASE=$(echo "$CURRENT_STATE" | jq -r '.node.state.phase')
	local NODE_ONLINE=$(echo "$CURRENT_STATE" | jq -r '.node.state.online')
	local NODE_SYNC=$(echo "$CURRENT_STATE" | jq -r '.node.state.is_synced')
	local POET_NAME=$(echo "$CURRENT_STATE" | jq -r '.node.poet.name')
	local POET_CYCLEGAP=$(echo "$CURRENT_STATE" | jq -r '.node.poet.cycle_gap')
	local POET_PHASESHIFT=$(echo "$CURRENT_STATE" | jq -r '.node.poet.phase_shift')
	local POET_GRACEPERIOD=$(echo "$CURRENT_STATE" | jq -r '.node.poet.grace_period')

	HEADER_PADDING='%-100s\n'
	COLUMN_PADDING='%-22s %8s %8s %8s %6s %1s %-20s %9s %7s %7s %s\n'

	send_log 3 ""
	send_log 3 "$(printf "$HEADER_PADDING" 'NODE STATE ------------------------------------------------------------------------------------------------') "
	send_log 3 "$(printf "$COLUMN_PADDING" 'phase'       'epoch'  'layer'  'online'  'sync' '' 'poet' 'cycle gap' 'shift' 'grace') "
	send_log 3 "$(printf "$HEADER_PADDING" '-----------------------------------------------------------------------------------------------------------') "
	send_log 3 "$(printf "$COLUMN_PADDING" "${NODE_PHASE}" "${NODE_EPOCH}" "${NODE_LAYER}" "${NODE_ONLINE}" "${NODE_SYNC}" "" "$POET_NAME" "$POET_CYCLEGAP" "$POET_PHASESHIFT" "$POET_GRACEPERIOD") "
	send_log 3 "$(printf "$HEADER_PADDING" '-----------------------------------------------------------------------------------------------------------') "
}

function layer_metrics {
	local LAYER_STATE=$(jq -n --argjson state "$CURRENT_STATE" '
	[
		{ "event": "epoch open", 			"layer": $state.network.state.epoch_opened_layer, 		"countdown": $state.network.state.epoch_opened_countdown_layer 		},
		{ "event": "epoch closed", 			"layer": $state.network.state.epoch_closed_layer, 		"countdown": $state.network.state.epoch_closed_countdown_layer 		},
		{ "event": "cycle gap open", 		"layer": $state.node.state.cycle_gap_opened_layer, 		"countdown": $state.node.state.cycle_gap_opened_countdown_layer 	},
		{ "event": "cycle gap closed", 		"layer": $state.node.state.cycle_gap_closed_layer, 		"countdown": $state.node.state.cycle_gap_closed_countdown_layer 	},
		{ "event": "registration open", 	"layer": $state.node.state.registration_opened_layer, 	"countdown": $state.node.state.registration_opened_countdown_layer 	},
		{ "event": "*", 					"layer": $state.network.state.layer, 					"countdown": 0 														}
	] | sort_by(.layer)
	')

	local HEADER_PADDING='%-100s\n'
    local COLUMN_PADDING='%-24s %12s %17s %5s %9s %29s %s\n'

	send_log 3 ""
	send_log 3 "$(printf "$HEADER_PADDING" 'LAYER STATE -----------------------------------------------------------------------------------------------') "
	send_log 3 "$(printf "$COLUMN_PADDING" 'event' 'until layer' 'until time' '' 'at layer' 'at time') "
	send_log 3 "$(printf "$HEADER_PADDING" '-----------------------------------------------------------------------------------------------------------') "

	echo "$LAYER_STATE" | jq -r '.[] | [.event, .layer, .countdown] | @tsv' | while IFS=$'\t' read -r EVENT LAYER COUNTDOWN; do	
		local COUNTDOWN_HOURS=$(if (( COUNTDOWN <= 0 )); then echo "-"; else convert_layer_to_countdown $COUNTDOWN; fi)
		local LAYER_DATE=$(convert_layer_to_datetime $COUNTDOWN)
	    send_log 3 "$(printf "$COLUMN_PADDING" "$EVENT" "$COUNTDOWN" "$COUNTDOWN_HOURS" "" "$LAYER" "$LAYER_DATE") "
	done

	send_log 3 "$(printf "$HEADER_PADDING" '-----------------------------------------------------------------------------------------------------------') "
}

function postservice_metrics {
	local HEADER_PADDING='%-100s\n'
	local COLUMN_PADDING='%-18s %-6s %4s %-0s %-14s %10s %10s %15s %10s %-8s %s\n'

	send_log 3 ""
	send_log 3 "$(printf "$HEADER_PADDING" 'POST SERVICE STATE ----------------------------------------------------------------------------------------') "
	send_log 3 "$(printf "$COLUMN_PADDING" 'name'             'id' 'su' '' 'phase'         'progress'    'nonces'    'disk speed'  'runtime' '(PoW)') "
	send_log 3 "$(printf "$HEADER_PADDING" '-----------------------------------------------------------------------------------------------------------') "
	
	echo "$CURRENT_STATE" | jq -r '.services[] | [
			.name, 
			.post.id[0:6], 
			.post.numunits, 
			.state.phase,
			(
				if .state.phase | IN("OFFLINE", "READY") 
				then [
					" "
				] 
				else [
					(if .state.progress == "0" then " " else (.state.progress|tostring + " %") end)
				] 
				end | .[]
			),
			(
				if .state.phase | IN("OFFLINE", "READY", "DONE") 
				then [
					" ", 
					" ", 
					" ", 
					" "
				] 
				else [
					(if .state.nonce == "" then " " else .state.nonce end),
					(if .state.runtime.read_rate_mib == 0 then " " else (.state.runtime.read_rate_mib|tostring + " MiB/s") end),
					(if .state.runtime.runtime_overall == 0 then " " else (.state.runtime.runtime_overall|tostring + "m") end),
					(if .state.runtime.runtime_pow == 0 then " " else ("(" + (.state.runtime.runtime_pow|tostring) + "m)") end)
				] 
				end | .[]
			)
		] | @tsv' | \
		while IFS=$'\t' read -r NAME POST_ID SU PHASE PROGRESS NONCES DISK_SPEED RUNTIME POW; do
			send_log 3 "$(printf "$COLUMN_PADDING" "$NAME" "$POST_ID" "$SU" "" "$PHASE" "$PROGRESS" "$NONCES" "$DISK_SPEED" "$RUNTIME" "$POW") "
		done

	send_log 3 "$(printf "$HEADER_PADDING" '-----------------------------------------------------------------------------------------------------------') "
}

function start_workflow {	
	# future workflow types:
	#   - parallel_workflow			"workflow: start all services in parallel (unmanaged)"
	#   - phased_workflow			"workflow: [optimal] start each service once running services have completed PROVING_POW"
	#   - linear_workflow			"workflow: start each service once running services have completed all proving"
	#   - monitor_only_workflow		"workflow: disabled - monitoring only"

	send_log 3 "phased_workflow: start each service once running services have completed PROVING_POW"
	set_current_state

	if cycle_gap_is_open
	then
		DELAY=300                                       # slow state checks
		if all_services_done; then return; fi           #  - nothing to manage until cycle gap ends

		DELAY=60                                        # fast state checks
		if any_services_proving_pow; then return; fi    #  - wait for running service(s) to finish proving_pow, before starting another
		if all_services_online; then return; fi         #  - monitor progress only: all services started

		start_next_service
	else
		DELAY=300
		local EPOCH_PHASE=$(echo "$CURRENT_STATE" | jq -r '.node.state.phase')

		if any_services_not_offline; 
		then 
			[[ $EPOCH_PHASE == "EPOCH_CLOSING" ]] && send_log 3 "EPOCH_CLOSING: services should be stopped unless still proving (late)"
			[[ $EPOCH_PHASE == "EPOCH_OPENING" ]] && send_log 2 "EPOCH_OPENING: services should not be running in this phase, user should investigate"
			stop_idle_services
		fi				
	fi
}

function main {	
	send_log 3 "starting psm..."
	build_info

	send_log 3 "loading psm configuration..."
	load_configuration

	while true
	do 
		send_log 3 "" 
		start_workflow 
		send_log 3 "waiting ${DELAY} seconds before checking state again..."
		export_state
		show_metrics
		sleep $DELAY
	done
}

main

exit