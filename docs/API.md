# spacemesh api reference
quick reference document for past and present apis related to `spacemesh-psm` development.

## grpc services
ports are not standardised, however this is a best efforts configuration, following defaults where possible.
```json
{
    "node-service-api": { 
        "grpc-public-listener": "0.0.0.0:9092",
        "grpc-private-listener": "127.0.0.1:9093",
        "grpc-post-listener": "0.0.0.0:9094",    // moves to smeshing-service if used
    },
    "smeshing-service-api": {
        "grpc-public-listener": "0.0.0.0:9092",
        "grpc-private-listener": "0.0.0.0:9093",
        "grpc-post-listener": "0.0.0.0:9094",
        "grpc-json-listener": "0.0.0.0:9095"
    },
    "post-service-api": { 

    },
    "k2pow-service-api": { 
                        
    }
}
```

## grpc server reflection
example usage of `list` on grpc for smeshing service
```
# grpcurl --plaintext 127.0.0.1:9092 list

grpc.reflection.v1.ServerReflection
grpc.reflection.v1alpha.ServerReflection
spacemesh.v2beta1.SmeshingIdentitiesService
spacemesh.v2beta1.SmeshingService
```

example usage of `describe` on grpc for SmeshingIdentitiesService api
```
# grpcurl --plaintext 127.0.0.1:9092 describe spacemesh.v2beta1.SmeshingIdentitiesService

spacemesh.v2beta1.SmeshingIdentitiesService is a service:
service SmeshingIdentitiesService {
  option (.google.api.api_visibility) = { restriction: "v2beta1" };
  rpc Eligibilities ( .spacemesh.v2beta1.EligibilitiesRequest ) returns ( .spacemesh.v2beta1.EligibilitiesResponse ) {
    option (.google.api.http) = { get: "/spacemesh.v2beta1.SmeshingIdentitiesService/Eligibilities" };
  }
  rpc PoetInfo ( .spacemesh.v2beta1.PoetInfoRequest ) returns ( .spacemesh.v2beta1.PoetInfoResponse ) {
    option (.google.api.http) = { get: "/spacemesh.v2beta1.SmeshingIdentitiesService/PoetInfo" };
  }
  rpc Proposals ( .spacemesh.v2beta1.ProposalsRequest ) returns ( .spacemesh.v2beta1.ProposalsResponse ) {
    option (.google.api.http) = { get: "/spacemesh.v2beta1.SmeshingIdentitiesService/Proposals" };
  }
  rpc States ( .spacemesh.v2beta1.IdentityStatesRequest ) returns ( .spacemesh.v2beta1.IdentityStatesResponse ) {
    option (.google.api.http) = { get: "/spacemesh.v2beta1.SmeshingIdentitiesService/States" };
  }
}
```

### Node Service Reflection List
#### grpc-public-listener

- spacemesh.v1.ActivationService
- spacemesh.v1.GlobalStateService
- spacemesh.v1.MeshService
- spacemesh.v1.NodeService
- spacemesh.v1.TransactionService
- spacemesh.v2alpha1.AccountService
- spacemesh.v2alpha1.ActivationService
- spacemesh.v2alpha1.LayerService
- spacemesh.v2alpha1.MalfeasanceService
- spacemesh.v2alpha1.NetworkService
- spacemesh.v2alpha1.NodeService
- spacemesh.v2alpha1.RewardService
- spacemesh.v2alpha1.TransactionService
- spacemesh.v2beta1.AccountService
- spacemesh.v2beta1.ActivationService
- spacemesh.v2beta1.LayerService
- spacemesh.v2beta1.MalfeasanceService
- spacemesh.v2beta1.NetworkService
- spacemesh.v2beta1.NodeService
- spacemesh.v2beta1.RewardService
- spacemesh.v2beta1.SmeshingIdentitiesService
- spacemesh.v2beta1.TransactionService

### Smeshing Service Reflection List
#### grpc-public-listener
- spacemesh.v2beta1.SmeshingIdentitiesService
- spacemesh.v2beta1.SmeshingService

#### grpc-private-listener
- spacemesh.v1.DebugService
- spacemesh.v1.SmesherService

#### grpc-post-listener
- spacemesh.v1.PostInfoService
- spacemesh.v1.PostService


## v1 api
### NodeService.Status
Service: Node (grpc-public-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v1.NodeService.Status
```
```json
{
    "status": {
        "connectedPeers": "26",
        "isSynced": true,
        "syncedLayer": {
            "number": 172756
        },
        "topLayer": {
            "number": 172756
        },
        "verifiedLayer": {
            "number": 172755
        }
    }
}

```
### MeshService.CurrentLayer
Service: Node (grpc-public-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v1.MeshService.CurrentLayer
```
```json
{
    "layernum": {
        "number": 172756
    }
}
```
### PostInfoService.PostStates
Service: Node / Smeshing (grpc-post-listener)
```
$ grpcurl --plaintext 127.0.0.1:9094 spacemesh.v1.PostInfoService.PostStates
```
```json
{
    "states": [
        {
            "id": "ksy+4VlcNkirq3iTVB3Tz/5q0g0yhlO3/DwgFU+BeFQL9epuufGI6owbohQ=",
            "state": "IDLE",
            "name": "smh-post-01.key"
        },
        {
            "id": "X5DKIqwoyktpuqcMA+7jViYcuaXZWQxlzsI0XLDvCEj8idNrMjxI8KUIatw=",
            "state": "IDLE",
            "name": "smh-post-02.key"
        },
        {
            "id": "5AuwTkEewU1P+/Pb8K3fW3dH8YXs6xhwXlqc5IjLTDcOiMrQjVaMpIEO+as=",
            "state": "IDLE",
            "name": "smh-post-03.key"
        }
    ]
}
```

## v2 api

### (v2beta1) SmeshingIdentitiesService.PoetInfo
Service: Node / Smeshing (grpc-post-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.SmeshingIdentitiesService.PoetInfo
```
```json
{
    "poets": [
        "https://poet-4.team24.co",
        "https://poet-5.team24.co",
        "https://backup-s1.team24.co"
    ],
    "config": {
        "phaseShift": "1036800s",
        "cycleGap": "86400s"
    }
}
```

### NetworkService.Info
Service: Node / Smeshing (grpc-post-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.NetworkService.Info
```
```json 
{
    "genesisTime": "2023-07-14T08:00:00Z",
    "layerDuration": "300s",
    "genesisId": "nuv/Ajq7F8y3dcYC2q3o7XCPClA=",
    "hrp": "sm",
    "effectiveGenesisLayer": 8063,
    "layersPerEpoch": 4032,
    "labelsPerUnit": "4294967296"
}
```

### SmeshingIdentitiesService.Eligibilities
Service: Node / Smeshing (grpc-post-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.SmeshingIdentitiesService.Eligibilities
```
```json
{
    "identities": {
        "c6545cb5f38eb15a89fb67e366c123c4c9abbe7c4971dcf464095e990f56b24f": {
            "epochs": {
                "42": {
                    "eligibilities": [{
                            "layer": 171769,
                            "count": 3
                        }
                    ]
                }
            }
        }
    }
}
```

### Service.Build
Service: Node (grpc-public-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.NodeService.Build
```
```json
{
    "build": "baf449ad8cd9274d668b080ef7fc28a48dba8869"
}
```
Service: Smeshing (grpc-public-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.SmeshingService.Build
```
```json
{
    "build": "baf449ad8cd9274d668b080ef7fc28a48dba8869"
}
```

### Service.Version
Service: Node (grpc-public-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.NodeService.Version
```
```json
{
    "version": "node-split-1.0.15"
}
```

Service: Smeshing (grpc-public-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.SmeshingService.Version
```
```json
{
    "version": "node-split-1.0.15"
}
```

### NodeService.Status
Service: Node (grpc-public-listener)
```
$ grpcurl --plaintext 127.0.0.1:9092 spacemesh.v2beta1.NodeService.Status
```
```json
{
    "connectedPeers": "26",
    "status": "SYNC_STATUS_SYNCED",
    "latestLayer": 172766,
    "appliedLayer": 172765,
    "processedLayer": 172765,
    "currentLayer": 172766
}
```




