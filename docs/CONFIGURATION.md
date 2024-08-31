## Configuration
`psm` configuration is done via `config.json` that is mounted into `psm` container.
A sample configuration is provided as a starting point, find a suitable location for this file to live.  
Sections are similar to those used in go-spacemesh configuration, or use similar nomenclature.  
Although `psm` has some basic quality checking, it is a users responsibility to ensure configuration is correct, and hass valid json.

### Node section
Configuration for the node that your post-services connect to:
- `name` is the name for your node (label only).
- `endpoint` should be updated with node connection details,
  - `metrics` is not currently used and can be left blank.
- `poet` same as go-spacemesh `config.mainnet.json` poet key, directly influences `psm` behaviour.
- `state` leave untouched, placeholder for capturing state data.

There should be only one node specified, this is not an array.

```json
    "node": {
        "name": "smh-node-01",
        "endpoint": {
            "ip_address": "smh-node-01",
            "node_listener_port": "9092",
            "post_listener_port": "9094",
            "metrics": ""
        },
        "poet": {
            "name": "team24 late phase",
            "phase_shift": "288h",
            "cycle_gap": "24h",
            "grace_period": "2h"
        },
        "state": {
            "online": false,
            "is_synced": false,
            "phase": "",
            "cycle_gap_opened_layer": 0,
            "cycle_gap_opened_countdown_layer": 0,
            "cycle_gap_closed_layer": 0,
            "cycle_gap_closed_countdown_layer": 0,
            "registration_opened_layer": 0,
            "registration_opened_countdown_layer": 0
        }
    },
```

### Services section
Configuration for post-services:
- `name` is the container name for your post-service.
- `endpoint` should be updated with node connection details.
  - `ip_address` should use post-service name or static ip.
  - `metrics` is required for proving state detection and should use post-service name or static ip and `operator-address` port.
- `post` used to identify and measure proving completion.
- `state` leave untouched, placeholder for capturing state data.

There can one or more post-services specified, this is an array.

```json
    "services": [
        {
            "name": "smh-post-01",
            "endpoint": {
                "ip_address": "smh-post-01",
                "metrics": "http://smh-post-01:9100/status"
            },
            "post": {
                "id": "AAAAAAAAAAAAAAAAA=",
                "numunits": 32
            },
            "state": {
                "online": false,
                "phase": "",
                "nonce": "",
                "progress": 0,
                "runtime": { 
                    "timestamp_start_pow": 0,
                    "timestamp_start_disk": 0,
                    "timestamp_finish": 0,
                    "read_rate_mib": 0,
                    "runtime_pow": 0,
                    "runtime_disk": 0,
                    "runtime_overall": 0
                }
            }
        },
        {
            "name": "smh-post-02",
            ...
        }
    ]

```

### network section
This section should not be modified, except by advanced users looking to run `psm` on testnet.
- `main` network configuration.
- `state` leave untouched, placeholder for capturing state data.

Continue to [RUN instructions](RUN.md) 