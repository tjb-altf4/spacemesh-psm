## Installation
A `psm` instance will needed to be created for each physical machine, and each node with a unique poet phase on that physical machine (if applicable).

Assumptions:
- Docker is already up and running.
- Node and post-services containers are already configured and working without `psm`.
- A custom docker network has been created for spacemesh nodes, post-service and `psm` to utilise (allows connection by container name).

### Option 1: Utilise pre-built psm Docker images
Automated image builds for both tagged releases, and commit triggered updates (edge) are available.  
For pull details, see https://github.com/tjb-altf4/spacemesh-psm/pkgs/container/spacemesh-psm

### Option 2: Manually build psm Docker image

```bash
# clone the repo
git clone https://github.com/tjb-altf4/spacemesh-psm.git

# open cloned folder
cd spacemesh-psm

# build the `psm` docker image
docker build -t smh-psm:latest .
```

Continue to [CONFIGURATION instructions](CONFIGURATION.md) 