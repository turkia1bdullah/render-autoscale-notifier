FROM node:22-alpine3.22

# Install dependencies
RUN apk add --no-cache bash curl jq tzdata

# Set timezone
ENV TZ=Asia/Riyadh

# Create user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create app directory
WORKDIR /app

# Copy files
COPY autoscale-watcher.sh .
RUN chmod +x autoscale-watcher.sh && chown -R appuser:appgroup /app

# Install dummy HTTP server
RUN npm install -g http-server

# Switch to non-root user
USER appuser

# Expose port required by Render
EXPOSE 3000

# Run autoscaler in background and serve dummy HTTP response
CMD sh -c "./autoscale-watcher.sh & http-server -p 3000"
