## Configuration
`psm` configuration is done via `config.json` that is mounted into `psm` container.
A sample configuration is provided as a starting point, find a suitable location for this file to live.  
Sections are similar to those used in go-spacemesh configuration, or use similar nomenclature.  
Although `psm` has some basic quality checking, it is a users responsibility to ensure configuration is correct, and hass valid json.

### Node section
Configuration for the node that your post-services connect to:
- `name` is the container name for your node.
- `endpoint` should be updated with node-service connection details,
  - `ip_address` ip address to connect to, or container name (if applicable).
  - `node_listener_port` port to connect to, also known as grpc-public-listener in go-spacemesh `config.mainnet.json`
  - `post_listener_port` port to connect to, also known as grpc-post-listener (if configured on node-service) in go-spacemesh `config.mainnet.json`.
- `poet` same as go-spacemesh `config.mainnet.json` poet key, directly influences `psm` behaviour.
- `post` 
  - `service_parallel` number of running services in pow phase simultaneously, useful when using multiple k2pow services behind a proxy.

There should be only one node specified, this is not an array.

```json
    "node": {
        "name": "smh-node-01",
        "endpoint": {
            "ip_address": "smh-node-01",
            "node_listener_port": "9092",
            "post_listener_port": "9094"
        },
        "poet": {
            "name": "team24 late phase",
            "phase_shift": "288h",
            "cycle_gap": "24h",
            "grace_period": "2h"
        },
        "post": {
            "service_parallel": 1
        }
    },
```

### Smesher section
This section is optional, and is only required if using smeshing-services.
If using smeshing-service, `post_listener_port` should be removed from `node` configuration, and instead should form part of smeshing-service configuration as shown in the example.

- `name` is the container name for your smeshing-service.
- `endpoint` should be updated with smeshing-service connection details,
  - `ip_address` ip address to connect to, or container name (if applicable).
  - `node_listener_port` port to connect to, also known as grpc-public-listener in go-spacemesh `config.mainnet.json`.
  - `post_listener_port` port to connect to, also known as grpc-post-listener (if configured on smeshing-service) in go-spacemesh `config.mainnet.json`.
- `poet` same as go-spacemesh `config.mainnet.json` poet key, directly influences `psm` behaviour.
- `post` 
  - `service_parallel` number of running services in pow phase simultaneously, useful when using multiple k2pow services behind a proxy.
```json
    "smesher": {
        "name": "smh-smesher-01",
        "endpoint": {
            "ip_address": "smh-smesher-01",
            "node_listener_port": "9092",
            "post_listener_port": "9094"
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

Continue to [RUN instructions](RUN.md) 