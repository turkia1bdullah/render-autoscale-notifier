FROM node:22-alpine3.22

# Install required tools
RUN apk add --no-cache bash curl jq tzdata

# Set timezone to GMT+3 (Asia/Riyadh)
ENV TZ=Asia/Riyadh

# Create non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create working directory and assign it to the user
WORKDIR /app
COPY autoscale-watcher.sh .
RUN chmod +x autoscale-watcher.sh && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Run the script
CMD ["sh", "./autoscale-watcher.sh"]
