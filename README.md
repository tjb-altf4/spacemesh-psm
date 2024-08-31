# Spacemesh Post Service Manager
### Intelligent management and monitoring of Spacemesh post-services

Spacemesh Post Service Manager (`psm`) is a community developed program to orchestrate Spacemesh post-services (1:N) to optimise CPU and disk read.  
`psm` optimises resource usage and speeds up overall proving through managing and queueing post-services.  
Resource optimisation is achieved by prioritising an individual post-service's proving phase 1 (PoW) before running the next post-service.

`psm` is designed to utilise features of the docker environment, and tested for that environment, other use cases are currently not supported and may have unpredictable behaviour.

**WARNING: Official Spacemesh software is maintained by the [Spacemesh Team](https://github.com/spacemeshos) and is currently considered alpha software, APIs may change without notice.  
While spacemesh-psm has been throughtly tested, it may contain undiscovered bugs, or future changes to the spacemesh post-service API may result in unexpected behavior.**

### Setup
- [INSTALLATION](docs/INSTALLATION.md)
- [CONFIGURATION](docs/CONFIGURATION.md) 
- [RUN](docs/RUN.md) 

### Donate
If you like spacemesh-psm and would like to say thanks, you can donate to this Spacemesh address: `sm1qqqqqqxjq5nkqmvnqnkl0t9hz8shwkuhqdervnchju963`

### Help
Please note that this repository is maintained by a fellow community member. I can only provide support for software bugs and issues directly related to the code in this repository. For general questions, usage inquiries, or issues not related to software bugs, we recommend checking out the official Spacemesh Discord (see https://spacemesh.io/) and seeking help from the community.
