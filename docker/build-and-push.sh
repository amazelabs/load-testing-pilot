#!/usr/bin/env bash
# Build the load-tester container image and push to ECR (China region).
#
# Usage:
#   ./build-and-push.sh <ECR_REPO_URI> [TAG]
#
# Example:
#   ./build-and-push.sh <ACCOUNT_ID>.dkr.ecr.cn-north-1.amazonaws.com.cn/load-testing-pilot v4.0.15
#
# Prerequisites:
#   - Docker running
#   - AWS CLI configured for the target China region account
#   - ECR repository already created (aws ecr create-repository --repository-name load-testing-pilot)

set -euo pipefail

ECR_REPO="${1:?Usage: $0 <ECR_REPO_URI> [TAG]}"
TAG="${2:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$PROJECT_ROOT/distributed-load-testing-on-aws-main"
UPSTREAM_DOCKER="$UPSTREAM_DIR/deployment/ecr/distributed-load-testing-on-aws-load-tester"

# --- Prepare build context ---
BUILD_CTX="$SCRIPT_DIR/build-context"
rm -rf "$BUILD_CTX"
mkdir -p "$BUILD_CTX"

echo "==> Copying files from upstream source..."
cp "$UPSTREAM_DOCKER/Dockerfile"   "$BUILD_CTX/"
cp "$UPSTREAM_DOCKER/load-test.sh" "$BUILD_CTX/"
cp "$UPSTREAM_DIR/k6.json"         "$BUILD_CTX/"
cp "$UPSTREAM_DIR/locust.json"     "$BUILD_CTX/"

# --- Build ---
IMAGE="$ECR_REPO:$TAG"
echo "==> Building image: $IMAGE"
docker build -t "$IMAGE" "$BUILD_CTX"

# --- Push ---
# Extract region and registry from the repo URI
REGISTRY="${ECR_REPO%%/*}"
REGION=$(echo "$REGISTRY" | sed -n 's/.*\.ecr\.\(.*\)\.amazonaws.*/\1/p')

echo "==> Logging into ECR ($REGISTRY)..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

echo "==> Pushing $IMAGE..."
docker push "$IMAGE"

# Cleanup
rm -rf "$BUILD_CTX"

echo ""
echo "✅ Done! Image pushed: $IMAGE"
echo ""
echo "Use this URI in CloudFormation parameter ContainerImage:"
echo "  $IMAGE"
