# KNEP Testing Commands

## Basic Connectivity Tests

### 1. Check Pod Status
```bash
# Check KNEP pods
kubectl get pods -n knep

# Check Kafka pods
kubectl get pods -n kafka

# Check certificate status
kubectl get certificate -n knep
kubectl get secret tls-secret -n knep
```

### 2. Port Forward for Testing
```bash
# Port forward to KNEP service (non-TLS)
kubectl port-forward svc/knep-gateway 9092:9092 -n knep

# Port forward Kong gateway (TLS)
kubectl port-forward svc/kong-proxy 9443:9443 -n kong
```

### 3. Test Kafka Connection (Non-TLS)
```bash
# Create a topic (will be prefixed as 'a-my-topic')
kafka-topics --create --topic my-topic --bootstrap-server localhost:9092

# List topics to verify prefixing
kafka-topics --list --bootstrap-server localhost:9092

# Produce messages
kafka-console-producer --topic my-topic --bootstrap-server localhost:9092

# Consume messages
kafka-console-consumer --topic my-topic --bootstrap-server localhost:9092 --from-beginning
```

### 4. Test with TLS (Kong Gateway)
```bash
# Test with kafka-console-producer
kafka-console-producer --topic my-topic \
  --bootstrap-server bootstrap.team-a.127-0-0-1.sslip.io:9443 \
  --producer-property security.protocol=SSL

# Test with kafka-console-consumer
kafka-console-consumer --topic my-topic \
  --bootstrap-server bootstrap.team-a.127-0-0-1.sslip.io:9443 \
  --consumer-property security.protocol=SSL \
  --from-beginning
```

## Health Check Commands

### KNEP Health Endpoints
```bash
# Health check
kubectl exec -n knep deployment/knep-gateway -- curl -s http://localhost:8080/health/probes/liveness

# Readiness check
kubectl exec -n knep deployment/knep-gateway -- curl -s http://localhost:8080/health/probes/readiness

# Metrics
kubectl exec -n knep deployment/knep-gateway -- curl -s http://localhost:8080/health/metrics
```

## Troubleshooting Commands

### Check Logs
```bash
# KNEP logs
kubectl logs -n knep deployment/knep-gateway -f

# Kafka logs
kubectl logs -n kafka kafka-cluster-kafka-0 -f

# Kong logs
kubectl logs -n kong deployment/kong-controller -f
```

### Debug Certificate Issues
```bash
# Check certificate details
kubectl describe certificate knep-certificate -n knep

# Check TLS secret
kubectl get secret tls-secret -n knep -o yaml

# Test certificate with openssl
kubectl get secret tls-secret -n knep -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```
