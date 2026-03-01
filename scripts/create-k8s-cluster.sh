#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="chat-app"
# Our current kind version already supports Kubernetes 1.35, but CloudNativePG
# latest version only supports Kubernetes 1.34.
NODE_IMAGE="kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48"

log() { echo "==> $*"; }

# --- kind cluster ---

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  log "Cluster '${CLUSTER_NAME}' already exists, skipping creation"
else
  log "Creating kind cluster '${CLUSTER_NAME}'"
  kind create cluster --name "${CLUSTER_NAME}" --image "${NODE_IMAGE}"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

# --- CloudNativePG operator ---

CNPG_VERSION="1.28.1"
CNPG_NO_PATCH_VERSION="${CNPG_VERSION%.*}"
CNPG_MANIFEST="https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${CNPG_NO_PATCH_VERSION}/releases/cnpg-${CNPG_VERSION}.yaml"

log "Installing CloudNativePG operator"
kubectl apply --server-side -f "${CNPG_MANIFEST}"

log "Waiting for CloudNativePG operator to be ready"
kubectl rollout status deployment/cnpg-controller-manager \
  -n cnpg-system \
  --timeout=120s

# --- CloudNative PG Cluster Image Catalog ---

# Choose the minimal catalog for the smallest image size.
# trixie is the latest Debian release as of 02/2026.
kubectl apply -f \
  https://raw.githubusercontent.com/cloudnative-pg/artifacts/refs/heads/main/image-catalogs/catalog-minimal-trixie.yaml

log "Applying PostgreSQL cluster"
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: chat-db
  namespace: default
spec:
  instances: 1
  storage:
    size: 1Gi
  bootstrap:
    initdb:
      database: chat
      owner: chat
EOF

log "Waiting for PostgreSQL cluster to be ready"
kubectl wait cluster/chat-db \
  --for=condition=Ready \
  --timeout=120s

log "Done! PostgreSQL is ready."
log "Connection secret: kubectl get secret chat-db-app -o yaml"