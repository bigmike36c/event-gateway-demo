# Kong Native Event Proxy (KNEP) - Kubernetes Deployment

A complete Kubernetes deployment setup for Kong Native Event Proxy (KNEP) with Apache Kafka integration, featuring multi-tenant topic routing, TLS termination, and Kong Ingress Controller gateway configuration.

## 🚀 Overview

This repository provides Kubernetes-ready manifests and automation scripts for deploying Kong Native Event Proxy as a secure, multi-tenant Kafka gateway. KNEP acts as a proxy layer between Kafka clients and Kafka clusters, enabling advanced routing, authentication, and topic management capabilities.

### Key Features

- **Multi-tenant Topic Routing**: Automatic topic prefixing for team isolation (`team-a` → `a-` prefix, `team-b` → `b-` prefix)
- **SNI-based Routing**: Route traffic based on Server Name Indication for different teams
- **TLS Termination**: Wildcard certificate support for `*.127-0-0-1.sslip.io` domains
- **Kong Gateway Integration**: Full integration with Kong Ingress Controller
- **Kafka Cluster**: Strimzi-based Kafka deployment with KRaft mode
- **Observability**: Built-in health checks and metrics endpoints
- **Certificate Management**: Automated wildcard certificate generation

## 📋 Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- [Strimzi Kafka Operator](https://strimzi.io/) installed
- [Kong Ingress Controller](https://docs.konghq.com/kubernetes-ingress-controller/) installed
- OpenSSL (for certificate generation)

## 🛠️ Quick Start

### 1. Deploy Kafka Cluster

```bash
kubectl create namespace kafka
kubectl apply -f kafka-cluster.yaml -n kafka
```

### 2. Create KNEP Namespace

```bash
kubectl create namespace knep
```

### 3. Generate TLS Certificates

```bash
./generate-wildcard-cert.sh
```

This creates:
- `wildcard.crt` - TLS certificate
- `wildcard.key` - Private key
- `wildcard-tls-secret.yaml` - Kubernetes secret manifest

### 4. Deploy KNEP Configuration and Secrets

```bash
# Apply TLS secret
kubectl apply -f wildcard-tls-secret.yaml -n knep

# Create Konnect secret (replace with your values)
kubectl create secret generic konnect-env-secret \
  --from-literal=KNEP__KONNECT__CONTROL_PLANE_ID=your-cp-id \
  --from-literal=KNEP__KONNECT__AUTH__PAT=your-pat-token \
  -n knep

# Apply KNEP configuration
kubectl create configmap knep-config --from-file=knep-config.yaml -n knep
```

### 5. Deploy KNEP Gateway

```bash
kubectl apply -f knep-deployment.yaml -n knep
```

### 6. Configure Kong Gateway

```bash
kubectl apply -f kic-gateway.yaml -n knep
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

## 📊 Monitoring & Health Checks

KNEP provides several endpoints for monitoring:

- **Health**: `http://knep-gateway:8080/health/probes/liveness`
- **Readiness**: `http://knep-gateway:8080/health/probes/readiness`
- **Metrics**: `http://knep-gateway:8080/health/metrics`

## 🧪 Testing

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

## 📁 File Structure

```
├── README.md                    # This file
├── kafka-cluster.yaml          # Strimzi Kafka cluster configuration
├── knep-config.yaml            # KNEP proxy configuration
├── knep-deployment.yaml        # KNEP deployment and service
├── kic-gateway.yaml            # Kong Gateway and TLS routing
├── wildcard-tls-secret.yaml    # TLS certificate secret (generated)
├── generate-wildcard-cert.sh   # Certificate generation script
├── create-tls-secret.sh        # Alternative TLS secret creation
├── cluster-issuer.yaml         # Cert-manager cluster issuer
├── knep-certificate.yaml       # Cert-manager certificate
├── kong-values.yaml            # Kong Helm values
└── konnect-secret.yaml         # Konnect configuration template
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
