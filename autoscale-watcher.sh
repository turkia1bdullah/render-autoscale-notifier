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

get_count() {
  SERVICE_ID=$1
  curl -s -H "Authorization: Bearer $RENDER_API_KEY" \
    https://api.render.com/v1/services | \
    jq -r ".[] | select(.service.id == \"$SERVICE_ID\") | .service.serviceDetails.numInstances"
}

# Initial counts
LAST_COUNT_APP=$(get_count "$SERVICE_ID_APP")
LAST_COUNT_DASHBOARD=$(get_count "$SERVICE_ID_DASHBOARD")
TOTAL_LAST=$((LAST_COUNT_APP + LAST_COUNT_DASHBOARD))

START_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Initial startup message
INIT_MESSAGE="🚀 *Render Autoscale Notifier Started*\n\
📅 *Time:* $START_TIME (GMT+3)\n\
🟣 *FenzoApp:* $LAST_COUNT_APP instance(s)\n\
🟠 *Dashboard:* $LAST_COUNT_DASHBOARD instance(s)\n\
📊 *Total:* $TOTAL_LAST"

curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
  -d chat_id="$CHAT_ID" \
  -d text="$INIT_MESSAGE" \
  -d parse_mode="Markdown"

echo "📦 Initial instance count:"
echo "🟣 App       = $LAST_COUNT_APP"
echo "🟠 Dashboard = $LAST_COUNT_DASHBOARD"
echo "📊 Total     = $TOTAL_LAST"

# Loop to check changes
while true; do
  CURRENT_APP=$(get_count "$SERVICE_ID_APP")
  CURRENT_DASHBOARD=$(get_count "$SERVICE_ID_DASHBOARD")
  TOTAL_CURRENT=$((CURRENT_APP + CURRENT_DASHBOARD))

  if [ "$TOTAL_CURRENT" -ne "$TOTAL_LAST" ]; then
    NOW=$(date "+%Y-%m-%d %H:%M:%S")

    # Icons based on change
    ICON_APP="➖"
    ICON_DASHBOARD="➖"
    ICON_TOTAL="➖"

    [ "$CURRENT_APP" -gt "$LAST_COUNT_APP" ] && ICON_APP="🔺"
    [ "$CURRENT_APP" -lt "$LAST_COUNT_APP" ] && ICON_APP="🔻"

    [ "$CURRENT_DASHBOARD" -gt "$LAST_COUNT_DASHBOARD" ] && ICON_DASHBOARD="🔺"
    [ "$CURRENT_DASHBOARD" -lt "$LAST_COUNT_DASHBOARD" ] && ICON_DASHBOARD="🔻"

    [ "$TOTAL_CURRENT" -gt "$TOTAL_LAST" ] && ICON_TOTAL="🔺"
    [ "$TOTAL_CURRENT" -lt "$TOTAL_LAST" ] && ICON_TOTAL="🔻"

    MESSAGE="🔄 *Render Autoscaling Change Detected*\n\
📅 *Time:* $NOW (GMT+3)\n\
🟣 *FenzoApp:* $ICON_APP $LAST_COUNT_APP → $CURRENT_APP\n\
🟠 *Dashboard:* $ICON_DASHBOARD $LAST_COUNT_DASHBOARD → $CURRENT_DASHBOARD\n\
📊 *Total:* $ICON_TOTAL $TOTAL_LAST → $TOTAL_CURRENT"

    echo -e "$MESSAGE"

    curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
      -d chat_id="$CHAT_ID" \
      -d text="$MESSAGE" \
      -d parse_mode="Markdown"

    # Update counts
    LAST_COUNT_APP=$CURRENT_APP
    LAST_COUNT_DASHBOARD=$CURRENT_DASHBOARD
    TOTAL_LAST=$TOTAL_CURRENT
  fi

  sleep 60
done
