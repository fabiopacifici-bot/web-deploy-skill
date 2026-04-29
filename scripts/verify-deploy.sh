#!/usr/bin/env bash
# verify-deploy.sh — verify a deployed URL returns a successful HTTP response
# Usage: bash verify-deploy.sh <url>
# Example: bash verify-deploy.sh https://my-app.onrender.com

URL=${1:?"Usage: $0 <url>"}
MAX_RETRIES=6
WAIT=10

echo "🔍 Verifying deployment at $URL"
echo "   (will retry up to $MAX_RETRIES times, ${WAIT}s apart)"
echo ""

for i in $(seq 1 $MAX_RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$URL" 2>/dev/null)
  LATENCY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 15 "$URL" 2>/dev/null)

  case "$STATUS" in
    200|201|301|302|307|308)
      echo "✅ Live — HTTP $STATUS — ${LATENCY}s response time"
      echo "🌐 URL: $URL"
      exit 0
      ;;
    000)
      echo "⏳ Attempt $i/$MAX_RETRIES — no response (DNS/network) — waiting ${WAIT}s..."
      ;;
    *)
      echo "⏳ Attempt $i/$MAX_RETRIES — HTTP $STATUS — waiting ${WAIT}s..."
      ;;
  esac

  [ $i -lt $MAX_RETRIES ] && sleep $WAIT
done

echo ""
echo "❌ Deployment not responding after $((MAX_RETRIES * WAIT))s."
echo "   Check your platform dashboard for deploy logs."
exit 1
