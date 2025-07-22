# Kong Native Event Proxy (KNEP) - Kubernetes Deployment

A complete Kubernetes deployment setup for Kong Native Event Proxy (KNEP) with Apache Kafka integration, featuring multi-tenant topic routing, TLS termination, and Kong Ingress Controller gateway configuration.

##  Overview

This repository provides Kubernetes-ready manifests and automation scripts for deploying Kong Native Event Proxy as a secure, multi-tenant Kafka gateway. KNEP acts as a proxy layer between Kafka clients and Kafka clusters, enabling advanced routing, authentication, and topic management capabilities.

### Key Features

- **Multi-tenant Topic Routing**: Automatic topic prefixing for team isolation (`team-a` → `a-` prefix, `team-b` → `b-` prefix)
- **SNI-based Routing**: Route traffic based on Server Name Indication for different teams
- **TLS Termination**: Wildcard certificate support
- **Kong Gateway Integration**: Full integration with Kong Ingress Controller
- **Kafka Cluster**: Strimzi-based Kafka deployment with KRaft mode
- **Observability**: Built-in health checks and metrics endpoints
- **Certificate Management**: Automated wildcard certificate generation

## 📋 Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- [Gateway API experimental](https://gateway-api.sigs.k8s.io/) installed
  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
  ```
- [Strimzi Kafka Operator](https://strimzi.io/) installed
- [Kong Ingress Controller](https://docs.konghq.com/kubernetes-ingress-controller/) installed
  - **Important**: KIC must be installed with the `--feature-gates=GatewayAlpha=true` flag to enable TLSRoute support. If using Helm, run the install command with `--set controller.ingressController.env.feature_gates="GatewayAlpha=true"`
- OpenSSL (for manual certificate generation)
- [cert-manager](https://cert-manager.io/) (optional, for automated certificate management)

## 🚀 Quick Start

### 1. Create Namespaces
```bash
kubectl create namespace kafka
kubectl create namespace knep
```

### 2. Deploy Kafka Cluster
```bash
# Install strimzi if not already installed
kubectl apply -f https://strimzi.io/install/latest\?namespace\=kafka -n kafka

# Deploy Kafka resources
kubectl apply -f kafka/ -n kafka
```

### 3. Setup TLS Certificates

**Option A: Using cert-manager (Recommended)**

```bash
# Install cert-manager if not already installed
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml

# Deploy certificate resources
kubectl apply -f certificates/ -n knep
```

**Option B: Manual Certificate Generation**
```bash
# Generate certificates
./scripts/generate-wildcard-cert.sh

# Apply the generated secret
kubectl apply -f ./wildcard-tls-secret.yaml -n knep
```

### 4. Deploy KNEP
```bash
# Create Konnect secret (replace with your values)
kubectl create secret generic konnect-env-secret \
  --from-literal=KONNECT_API_HOSTNAME=your-region \
  --from-literal=KONNECT_CONTROL_PLANE_ID=your-cp-id \
  --from-literal=KONNECT_API_TOKEN=your-pat-token \
  -n knep

# Deploy KNEP components
kubectl apply -f knep/ -n knep
```

### 5. Configure Kong Gateway with TLSRoute support
```bash
# Create Konnect client certificate secret (replace with your values)
kubectl create secret tls konnect-client-tls -n kong --cert=./tls.crt --key=./tls.key

# Add Kong Ingress Controller repository
helm repo add kong https://charts.konghq.com
helm repo update

# Add the TCP TLS listener to the Kong values.yaml file
  proxy:
    stream:
    - containerPort: 9092
      servicePort: 9092
      protocol: TCP
      parameters:
      - ssl

# Install Kong with TLSRoute support
helm install kong kong/ingress -n kong --create-namespace --set controller.ingressController.env.feature_gates="FillIDs=true,GatewayAlpha=tru" --values ./values.yaml

# Deploy Gateway API resources
kubectl apply -f kong/ -n knep
```

### Cleanup
```bash
./scripts/cleanup.sh
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kafka Client  │───▶│   Kong Gateway   │───▶│  KNEP Proxy     │
│   (team-a)      │    │  (TLS Route)     │    │  (SNI Router)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────┐
                                               │  Kafka Cluster  │
                                               │   (Strimzi)     │
                                               └─────────────────┘
```

### Traffic Flow

1. **Client Connection**: Kafka clients connect to `bootstrap.team-a.127-0-0-1.sslip.io:9443`
2. **Kong Gateway**: Routes TLS traffic based on SNI to KNEP service
3. **KNEP Proxy**: Terminates TLS, applies topic prefixing, forwards to Kafka
4. **Kafka Cluster**: Processes requests with prefixed topics (`a-my-topic`)

## 🔧 Configuration

### Virtual Clusters

KNEP supports multiple virtual clusters with different routing rules:

- **team-a**: Topics prefixed with `a-` (e.g., `my-topic` → `a-my-topic`)
- **team-b**: Topics prefixed with `b-` (e.g., `my-topic` → `b-my-topic`)

### SNI Routing

Traffic is routed based on the SNI hostname:
- `*.team-a.127-0-0-1.sslip.io` → team-a virtual cluster
- `*.team-b.127-0-0-1.sslip.io` → team-b virtual cluster

## � Certificate Management

### Manual Certificate Generation

The `generate-wildcard-cert.sh` script creates self-signed certificates suitable for development and testing. The certificates include all necessary Subject Alternative Names (SANs) for the multi-tenant setup:

- `*.127-0-0-1.sslip.io` (wildcard for all subdomains)
- `*.team-a.127-0-0-1.sslip.io` and `*.team-b.127-0-0-1.sslip.io` (team-specific wildcards)
- `bootstrap.team-a.127-0-0-1.sslip.io` and `bootstrap.team-b.127-0-0-1.sslip.io` (bootstrap endpoints)

**Pros:**
- Quick setup for development
- No additional dependencies
- Full control over certificate properties

**Cons:**
- Manual renewal required (365-day validity)
- Self-signed certificates (browser warnings)
- No automatic rotation

### cert-manager Integration

The cert-manager approach uses a self-signed ClusterIssuer to automatically generate and manage certificates. This provides:

**Pros:**
- Automatic certificate renewal
- Kubernetes-native certificate lifecycle management
- Easy integration with other issuers (Let's Encrypt, CA, etc.)
- Automatic secret creation and updates

**Cons:**
- Requires cert-manager installation
- Additional complexity for simple setups

**Production Note:** For production deployments, consider configuring cert-manager with a proper CA or ACME issuer instead of the self-signed issuer.

## �📊 Monitoring & Health Checks

KNEP provides several endpoints for monitoring:

- **Health**: `http://knep-gateway:8080/health/probes/liveness`
- **Readiness**: `http://knep-gateway:8080/health/probes/readiness`
- **Metrics**: `http://knep-gateway:8080/health/metrics`

## 🧪 Testing

### Quick Status Check
```bash
# Check deployment status
kubectl get pods -n knep
kubectl get pods -n kafka

# Check certificate status
kubectl get certificate -n knep
kubectl get secret tls-secret -n knep
```

### Test Kafka Connection
```bash
# Port forward to KNEP service
kubectl port-forward svc/knep-gateway 9092:9092 -n knep

# Create a topic (will be prefixed as 'a-my-topic')
kafka-topics --create --topic my-topic --bootstrap-server localhost:9092

# List topics to verify prefixing
kafka-topics --list --bootstrap-server localhost:9092
```

### Test with TLS
```bash
# Port forward Kong gateway
kubectl port-forward svc/kong-proxy 9443:9443 -n kong

# Test with kafka-console-producer
kafka-console-producer --topic my-topic \
  --bootstrap-server bootstrap.team-a.127-0-0-1.sslip.io:9443 \
  --producer-property security.protocol=SSL
```

For more detailed testing commands and examples, see [`examples/test-commands.md`](examples/test-commands.md).

## 📋 Components

### Kafka Cluster (`kafka/`)
- `kafka-cluster.yaml` - Strimzi Kafka configuration with KRaft mode

### KNEP Proxy (`knep/`)
- `knep-config.yaml` - Multi-tenant proxy configuration with topic routing
- `knep-deployment.yaml` - Deployment, service, and health checks
- `konnect-secret.yaml` - Kong Konnect credentials template

### Kong Gateway (`kong/`)
- `kic-gateway.yaml` - Gateway configuration with SNI-based TLS routing
- `kong-values.yaml` - Helm values for Kong installation

### Certificates (`certificates/`)
- `cluster-issuer.yaml` - cert-manager self-signed issuer
- `knep-certificate.yaml` - Certificate definition with multi-domain SANs
- `tls-secret.yaml` - Manual certificate secret template

### Scripts (`scripts/`)
- `cleanup.sh` - Complete cleanup script
- `generate-wildcard-cert.sh` - Manual certificate generation
- `create-tls-secret.sh` - Alternative TLS secret creation
- `kafkactl-helper.sh` - Kafka administration helper

### Examples (`examples/`)
- `test-commands.md` - Comprehensive testing and troubleshooting commands
- `kafka-client-configs/` - Sample client configurations for different teams

## 📁 Repository Structure

```
k8s-knep/
├── kafka/              # Kafka cluster configuration
│   └── kafka-cluster.yaml
├── knep/               # KNEP proxy components
│   ├── knep-config.yaml
│   ├── knep-deployment.yaml
│   └── konnect-secret.yaml
├── kong/               # Kong Gateway setup
│   ├── kic-gateway.yaml
│   └── kong-values.yaml
├── certificates/       # TLS certificate management
│   ├── cluster-issuer.yaml
│   ├── knep-certificate.yaml
│   └── tls-secret.yaml
├── scripts/            # Automation scripts
│   ├── generate-wildcard-cert.sh
│   ├── create-tls-secret.sh
│   ├── kafkactl-helper.sh
│   └── cleanup.sh
└── examples/           # Usage examples and configs
    ├── kafka-client-configs/
    └── test-commands.md
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Kong Native Event Proxy Docs](https://docs.konghq.com/gateway/latest/kong-native-event-proxy/)
- **Issues**: [GitHub Issues](https://github.com/hguerrero/kong-native-event-proxy-kubernetes/issues)
- **Community**: [Kong Community Forum](https://discuss.konghq.com/)

## 🏷️ Tags

`kafka` `kong` `kubernetes` `proxy` `multi-tenant` `tls` `strimzi` `gateway` `event-streaming`
