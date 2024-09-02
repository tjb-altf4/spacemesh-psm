## Installation
A `psm` instance will needed to be created for each physical machine, and each node with a unique poet phase on that physical machine (if applicable).

Assumptions:
- Docker is already up and running.
- Node and post-services containers are already configured and working without `psm`.
- A custom docker network has been created for spacemesh nodes, post-service and `psm` to utilise (allows connection by container name).
- Set up instructions are written for a Linux environment, but Windows/WSL should work with minor changes to build/run cmds (not tested).

### Build psm Docker image

```bash
# clone the repo
git clone https://github.com/tjb-altf4/spacemesh-psm.git

# open cloned folder
cd spacemesh-psm

# build the `psm` docker image
docker build -t smh-psm:latest .
```

Continue to [CONFIGURATION instructions](CONFIGURATION.md) 