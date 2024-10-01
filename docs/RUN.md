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
2024-10-07 16:26:44       INFO       [node_metrics]                 
2024-10-07 16:26:44       INFO       [node_metrics]                 NODE STATE ------------------------------------------------------------------------------------------------ 
2024-10-07 16:26:44       INFO       [node_metrics]                 phase                     epoch    layer   online   sync   poet                 cycle gap   shift   grace  
2024-10-07 16:26:44       INFO       [node_metrics]                 ----------------------------------------------------------------------------------------------------------- 
2024-10-07 16:26:44       INFO       [node_metrics]                 CYCLE_GAP                    31   128199     true   true   team24 early phase         24h    288h      2h  
2024-10-07 16:26:45       INFO       [node_metrics]                 ----------------------------------------------------------------------------------------------------------- 
2024-10-07 16:26:45       INFO       [layer_metrics]                
2024-10-07 16:26:45       INFO       [layer_metrics]                LAYER STATE ----------------------------------------------------------------------------------------------- 
2024-10-07 16:26:45       INFO       [layer_metrics]                event                     until layer        until time        at layer                       at time  
2024-10-07 16:26:45       INFO       [layer_metrics]                ----------------------------------------------------------------------------------------------------------- 
2024-10-07 16:26:45       INFO       [layer_metrics]                epoch open                      -3207                 -          124992        15-Dec-2025 16:26 AWST  
2024-10-07 16:26:45       INFO       [layer_metrics]                cycle gap open                    -39                 -          128160        26-Dec-2025 16:26 AWST  
2024-10-07 16:26:45       INFO       [layer_metrics]                *                                   0                 -          128199        26-Dec-2025 19:41 AWST  
2024-10-07 16:26:45       INFO       [layer_metrics]                registration open                 225           18h 45m          128424        27-Dec-2025 14:26 AWST  
2024-10-07 16:26:45       INFO       [layer_metrics]                cycle gap closed                  249           20h 45m          128448        27-Dec-2025 16:26 AWST  
2024-10-07 16:26:45       INFO       [layer_metrics]                epoch closed                      824        2d 20h 40m          129023        29-Dec-2025 16:21 AWST  
2024-10-07 16:26:45       INFO       [layer_metrics]                ----------------------------------------------------------------------------------------------------------- 
2024-10-07 16:26:45       INFO       [postservice_metrics]          
2024-10-07 16:26:45       INFO       [postservice_metrics]          POST SERVICE STATE ---------------------------------------------------------------------------------------- 
2024-10-07 16:26:45       INFO       [postservice_metrics]          name               id       su  phase            progress     nonces      disk speed    runtime (PoW)     
2024-10-07 16:26:45       INFO       [postservice_metrics]          ----------------------------------------------------------------------------------------------------------- 
2024-10-07 16:26:45       INFO       [postservice_metrics]          smh-post-01        V1XyOD   32  PROVING_DISK      17.38 %     0..288    152.35 MiB/s        39m           
2024-10-07 16:26:45       INFO       [postservice_metrics]          smh-post-02        zLC0oR   64  PROVING_DISK       7.67 %     0..288    125.47 MiB/s        39m           
2024-10-07 16:26:46       INFO       [postservice_metrics]          smh-post-03        XhtD+T  192  DONE             100.00 %                                                 
2024-10-07 16:26:46       INFO       [postservice_metrics]          smh-post-04        JdVfo7  192  PROVING_DISK       1.11 %   144..288     53.77 MiB/s        39m           
2024-10-07 16:26:46       INFO       [postservice_metrics]          smh-post-05        Jn/vUe  192  PROVING_DISK        .35 %     0..288                        38m (24m)     
2024-10-07 16:26:46       INFO       [postservice_metrics]          smh-post-06        DM/i4R  192  PROVING_POW                   0..288                        13m (13m)     
2024-10-07 16:26:46       INFO       [postservice_metrics]          ----------------------------------------------------------------------------------------------------------- 
```
You might see you post-services briefly start in READY state before `psm` shuts them down, waiting for next cycle gap.