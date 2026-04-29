#!/usr/bin/env bash
# deploy-gcloud-run.sh
# Deploy a Docker image to Google Cloud Run (free: 2M requests/month)
# Usage: bash deploy-gcloud-run.sh <image-name> <service-name> [region]
# Example: bash deploy-gcloud-run.sh my-app my-app-service europe-west1
#
# Prerequisites: gcloud CLI installed and authenticated
#   gcloud auth login
#   gcloud config set project YOUR_PROJECT_ID

IMAGE=${1:?"Usage: $0 <image-name> <service-name> [region]"}
SERVICE=${2:?"Usage: $0 <image-name> <service-name> [region]"}
REGION=${3:-europe-west1}

PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT" ]; then
  echo "❌ No active gcloud project."
  echo "   Run: gcloud auth login && gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

IMAGE_URI="gcr.io/$PROJECT/$IMAGE"

echo "📦 Building Docker image: $IMAGE_URI"
docker build -t "$IMAGE_URI" . || { echo "❌ Docker build failed"; exit 1; }

echo "⬆️  Pushing to Google Container Registry..."
docker push "$IMAGE_URI" || { echo "❌ Docker push failed. Run: gcloud auth configure-docker"; exit 1; }

echo "🚀 Deploying to Cloud Run ($REGION)..."
gcloud run deploy "$SERVICE" \
  --image "$IMAGE_URI" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --port 8080 || { echo "❌ Cloud Run deploy failed"; exit 1; }

URL=$(gcloud run services describe "$SERVICE" \
  --region "$REGION" \
  --format 'value(status.url)' 2>/dev/null)

echo ""
echo "✅ Deployed to Google Cloud Run"
echo "🌐 URL: $URL"

if [ -n "$URL" ]; then
  bash "$(dirname "$0")/verify-deploy.sh" "$URL"
fi
