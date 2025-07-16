#!/bin/bash
set -e

echo "🧹 Cleaning up KNEP deployment..."

# Remove Kong Gateway
echo "🦍 Removing Kong Gateway..."
kubectl delete -f kong/ -n knep --ignore-not-found=true

# Remove KNEP
echo "🎯 Removing KNEP..."
kubectl delete -f knep/ -n knep --ignore-not-found=true

# Remove certificates
echo "🔐 Removing certificates..."
kubectl delete -f certificates/ --ignore-not-found=true

# Remove Kafka
echo "☕ Removing Kafka cluster..."
kubectl delete -f kafka/ -n kafka --ignore-not-found=true

# Remove namespaces
echo "📦 Removing namespaces..."
kubectl delete namespace knep --ignore-not-found=true
kubectl delete namespace kafka --ignore-not-found=true

echo "✅ Cleanup complete!"
