#!/bin/bash
set -e

echo "Fixing webhook timeout issues..."

# Check if the webhook service exists
if kubectl get service aws-load-balancer-webhook-service -n kube-system >/dev/null 2>&1; then
  echo "Restarting AWS Load Balancer Controller deployment..."
  kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
fi

echo "Increasing webhook timeouts..."
kubectl get mutatingwebhookconfiguration -o name | grep aws-load-balancer-webhook | xargs -I{} kubectl patch {} --type json -p '[{"op":"replace","path":"/webhooks/0/timeoutSeconds","value":30}]' || true
kubectl get validatingwebhookconfiguration -o name | grep aws-load-balancer-webhook | xargs -I{} kubectl patch {} --type json -p '[{"op":"replace","path":"/webhooks/0/timeoutSeconds","value":30}]' || true

echo "Waiting for controller to be ready again..."
kubectl wait --for=condition=available --timeout=180s deployment/aws-load-balancer-controller -n kube-system || true

echo "Webhook fixes completed. If you encounter webhook errors during your terraform apply, run this script and try again."
