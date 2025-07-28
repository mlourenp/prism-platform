#!/bin/bash
set -e

echo "Resetting webhook configurations to unblock deployment..."

# Delete any existing webhook configurations for AWS Load Balancer Controller
echo "Removing AWS Load Balancer webhook configurations..."
kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook 2>/dev/null || true
kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook 2>/dev/null || true

# Delete any existing cert-manager webhook configurations
echo "Removing cert-manager webhook configurations..."
kubectl delete mutatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true
kubectl delete validatingwebhookconfiguration cert-manager-webhook 2>/dev/null || true

# Delete the deployments to allow for clean reinstall
echo "Removing AWS Load Balancer Controller and cert-manager deployments..."
kubectl delete deployment aws-load-balancer-controller -n kube-system 2>/dev/null || true
kubectl delete deployment cert-manager -n cert-manager 2>/dev/null || true
kubectl delete deployment cert-manager-webhook -n cert-manager 2>/dev/null || true
kubectl delete deployment cert-manager-cainjector -n cert-manager 2>/dev/null || true

# Delete services
echo "Removing webhook services..."
kubectl delete service aws-load-balancer-webhook-service -n kube-system 2>/dev/null || true
kubectl delete service cert-manager-webhook -n cert-manager 2>/dev/null || true

echo "Reset complete. Please run the deploy-addons.sh script again."
