#!/bin/sh

# Render will inject these at runtime
# Use defaults for local testing
RENDER_API_KEY="${RENDER_API_KEY:-your-dev-api-key}"
BOT_TOKEN="${BOT_TOKEN:-your-dev-telegram-bot-token}"
CHAT_ID="${CHAT_ID:-your-dev-chat-id}"
SERVICE_ID_APP="${SERVICE_ID_APP:-srv-d1rvad2li9vc7395rta0}"
SERVICE_ID_DASHBOARD="${SERVICE_ID_DASHBOARD:-srv-d1rv0qripnbc73fgdetg}"

# Set timezone to Asia/Riyadh (GMT+3)
export TZ=Asia/Riyadh

# Function to retrieve instance count
get_count() {
  SERVICE_ID=$1
  RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $RENDER_API_KEY" \
    "https://api.render.com/v1/services/$SERVICE_ID/instances")

  BODY=$(echo "$RESPONSE" | head -n -1)
  STATUS=$(echo "$RESPONSE" | tail -n 1)

  if [ "$STATUS" -ne 200 ]; then
    echo "0"
  else
    echo "$BODY" | jq '. | length'
  fi
}

# Get initial counts
LAST_COUNT_APP=$(get_count "$SERVICE_ID_APP")
LAST_COUNT_DASHBOARD=$(get_count "$SERVICE_ID_DASHBOARD")
TOTAL_LAST=$((LAST_COUNT_APP + LAST_COUNT_DASHBOARD))
START_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Send startup notification
INIT_MESSAGE=$(printf "🚀 *Render Autoscale Notifier Started*\n📅 *Time:* %s (GMT+3)\n🟣 *FenzoApp:* %s instance(s)\n🟠 *Dashboard:* %s instance(s)\n📊 *Total:* %s" \
  "$START_TIME" "$LAST_COUNT_APP" "$LAST_COUNT_DASHBOARD" "$TOTAL_LAST")

curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
  -d chat_id="$CHAT_ID" \
  -d text="$INIT_MESSAGE" \
  -d parse_mode="Markdown"

echo "📦 Initial instance count:"
echo "🟣 App       = $LAST_COUNT_APP"
echo "🟠 Dashboard = $LAST_COUNT_DASHBOARD"
echo "📊 Total     = $TOTAL_LAST"

# Monitor loop
while true; do
  CURRENT_APP=$(get_count "$SERVICE_ID_APP")
  CURRENT_DASHBOARD=$(get_count "$SERVICE_ID_DASHBOARD")
  TOTAL_CURRENT=$((CURRENT_APP + CURRENT_DASHBOARD))

  if [ "$TOTAL_CURRENT" -ne "$TOTAL_LAST" ]; then
    NOW=$(date "+%Y-%m-%d %H:%M:%S")

    # Decide icons
    ICON_APP="➖"
    ICON_DASHBOARD="➖"
    ICON_TOTAL="➖"

    [ "$CURRENT_APP" -gt "$LAST_COUNT_APP" ] && ICON_APP="🔺"
    [ "$CURRENT_APP" -lt "$LAST_COUNT_APP" ] && ICON_APP="🔻"

    [ "$CURRENT_DASHBOARD" -gt "$LAST_COUNT_DASHBOARD" ] && ICON_DASHBOARD="🔺"
    [ "$CURRENT_DASHBOARD" -lt "$LAST_COUNT_DASHBOARD" ] && ICON_DASHBOARD="🔻"

    [ "$TOTAL_CURRENT" -gt "$TOTAL_LAST" ] && ICON_TOTAL="🔺"
    [ "$TOTAL_CURRENT" -lt "$TOTAL_LAST" ] && ICON_TOTAL="🔻"

    # Build message
    MESSAGE=$(printf "🔄 *Render Autoscaling Change Detected*\n📅 *Time:* %s (GMT+3)\n🟣 *FenzoApp:* %s %s → %s\n🟠 *Dashboard:* %s %s → %s\n📊 *Total:* %s %s → %s" \
      "$NOW" "$ICON_APP" "$LAST_COUNT_APP" "$CURRENT_APP" "$ICON_DASHBOARD" "$LAST_COUNT_DASHBOARD" "$CURRENT_DASHBOARD" "$ICON_TOTAL" "$TOTAL_LAST" "$TOTAL_CURRENT")

    echo -e "$MESSAGE"

    # Send Telegram alert
    curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
      -d chat_id="$CHAT_ID" \
      -d text="$MESSAGE" \
      -d parse_mode="Markdown"

    # Update trackers
    LAST_COUNT_APP=$CURRENT_APP
    LAST_COUNT_DASHBOARD=$CURRENT_DASHBOARD
    TOTAL_LAST=$TOTAL_CURRENT
  fi

  sleep 60
done
