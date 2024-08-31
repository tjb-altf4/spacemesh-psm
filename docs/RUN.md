## Run
Once configured, we can attempt to run `psm`:

### Run psm docker container
```bash
docker run \
    --name=smh-psm-01 \
    --net=spacemesh \
    -e TZ=UTC \
    -v /mnt/psm/node-01/:/psm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --restart=unless-stopped \
    library/smh-psm:latest
```
- mounting `docker.sock` in container is required for `psm` to start and stop other post-services containers, there are potentially secruity risks with this method (see [docs.docker.com](https://docs.docker.com/)).

### Run post-service docker container with psm requirements (sample)
```bash
docker run \
    --name=smh-post-01 \
    --net=spacemesh \
    -e TZ=UTC \
    -v /mnt/user/spacemesh/post-01/:/root/post \
    --restart=unless-stopped \
    spacemeshos/post-service:v0.7.11 \
        --dir /root/post \
        --address http://smh-post-01:9094 \
        --operator-address 0.0.0.0:9100 \
        --threads 0 \
        --nonces 288 \
        --randomx-mode fast
```
- post-service container `--name` is the same set in `psm` `config.json`
- `--operator-address` needs to be set in order to check proving state
- detailed configuration available from Spacemesh team here https://github.com/spacemeshos/post-rs/tree/main/service

### Docker Compose
Docker Compose can be utilised to create and run `psm` alongside go-spacemesh node and post-services.  
`psm` will stop and start post-services as required after the stack is started as long as `--restart` flag is set correctly.

### Success criteria
How do I know its worked?  
If all is running correctly `psm` will start logging information such as epoch data, time until proving, and current state, e.g.:
```bash
# follow spacemesh-psm logs
docker logs -f -n 90 smh-psm-01
```
```log
2024-08-31 13:24:18       INFO       [main]                         
2024-08-31 13:24:18       INFO       [start_workflow]               phased_workflow: start each service once running services have completed PROVING_POW
2024-08-31 13:24:18       INFO       [set_current_state]            loading network state...
2024-08-31 13:24:22       INFO       [set_node_sync_state]          NODE smh-node-01 is synced
2024-08-31 13:24:22       INFO       [set_network_state]            epoch 29 layer 119200
2024-08-31 13:24:22       INFO       [set_current_state]            loading poet state...
2024-08-31 13:24:23       INFO       [set_poet_state]               epoch 29 open from: 116928(-2272) to 120959(1759)
2024-08-31 13:24:23       INFO       [set_poet_state]               epoch 29 cycle gap open from: 120096(896) to 120384(1184)
2024-08-31 13:24:23       INFO       [set_poet_state]               epoch 29 cycle gap registration open from: 120360(1160) to 120384(1184)
2024-08-31 13:24:23       INFO       [set_poet_state]               epoch 29 current phase: EPOCH_OPENING
2024-08-31 13:24:23       INFO       [set_current_state]            loading post-services state...
2024-08-31 13:24:23       INFO       [set_proving_state]            smh-post-01 phase: OFFLINE
2024-08-31 13:24:24       INFO       [set_proving_state]            smh-post-02 phase: OFFLINE
2024-08-31 13:24:26       INFO       [main]                         waiting 300 seconds before checking state again...
2024-08-31 13:29:26       INFO       [main] 
```
You might see you post-services briefly start in READY state before `psm` shuts them down, waiting for next cycle gap.