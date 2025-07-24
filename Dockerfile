# Use Node.js LTS version
FROM node:20-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=development

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-full \
    curl \
    gnupg2 \
    sudo \
    git \
    build-essential \
    wget \
    ca-certificates \
    && curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
    && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list \
    && apt-get update \
    && apt-get install -y ngrok \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Cloud Foundry CLI
RUN wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add - \
    && echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list \
    && apt-get update \
    && apt-get install -y cf8-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && cf --version

# Set working directory
WORKDIR /app

# Install global Node.js dependencies
RUN npm install -g @sap/cds-dk

# Create directory structure (simplified approach)
RUN mkdir -p \
    agent-catalog/srv \
    agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/app/router/dev \
    agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/patches \
    agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/resources/a2a-specification \
    agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/srv/cap \
    agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/srv/well-known \
    agents/sap-agent-builder-a2a/agent-builder-agent-exports \
    agents/gcp-adk-a2a/Warehouse_Insight_Agent \
    agents/azure-ai-foundry-a2a/dispute-email-agent

# Copy package files first to leverage Docker cache
COPY --chown=node:node agent-catalog/package*.json ./agent-catalog/ 2>/dev/null || true
COPY --chown=node:node agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/package*.json ./agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/ 2>/dev/null || true
COPY --chown=node:node agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/app/router/package*.json ./agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/app/router/ 2>/dev/null || true
COPY --chown=node:node agents/gcp-adk-a2a/requirements.txt ./agents/gcp-adk-a2a/ 2>/dev/null || true
COPY --chown=node:node agents/azure-ai-foundry-a2a/requirements.txt ./agents/azure-ai-foundry-a2a/ 2>/dev/null || true

# Install Node.js dependencies
RUN cd agent-catalog && [ -f package.json ] && npm ci --only=production || echo "No package.json found in agent-catalog"
RUN cd agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector && [ -f package.json ] && npm ci --only=production || echo "No package.json found in agent-connector"
RUN cd agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/app/router && [ -f package.json ] && npm ci --only=production || echo "No package.json found in router"

# Set up Python virtual environments and install dependencies
RUN cd agents/gcp-adk-a2a && \
    if [ -f requirements.txt ]; then \
        python3 -m venv .venv && \
        . .venv/bin/activate && \
        pip install --no-cache-dir -r requirements.txt && \
        deactivate; \
    else \
        echo "No requirements.txt found in gcp-adk-a2a"; \
    fi

RUN cd agents/azure-ai-foundry-a2a && \
    if [ -f requirements.txt ]; then \
        python3 -m venv .venv && \
        . .venv/bin/activate && \
        pip install --no-cache-dir -r requirements.txt && \
        deactivate; \
    else \
        echo "No requirements.txt found in azure-ai-foundry-a2a"; \
    fi

# Copy the rest of the application
COPY --chown=node:node . .

# Create a startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Function to start services\n\
start_services() {\n\
    echo "Starting BTP A2A Dispute Resolution services..."\n\
    \n\
    # Start agent-catalog service\n\
    if [ -f "/app/agent-catalog/package.json" ]; then\n\
        echo "Starting agent-catalog service..."\n\
        cd /app/agent-catalog\n\
        npm start &\n\
        AGENT_CATALOG_PID=$!\n\
        echo "Agent catalog started with PID: $AGENT_CATALOG_PID"\n\
    fi\n\
    \n\
    # Start other services as needed\n\
    # Add more service startup commands here\n\
    \n\
    # Keep the container running\n\
    wait\n\
}\n\
\n\
# Handle shutdown gracefully\n\
trap '\''echo "Shutting down services..."; kill $(jobs -p); exit 0'\'' SIGTERM SIGINT\n\
\n\
# Start services or run custom command\n\
if [ "$#" -eq 0 ] || [ "$1" = "start" ]; then\n\
    start_services\n\
else\n\
    exec "$@"\n\
fi' > /app/start.sh && chmod +x /app/start.sh

# Switch to non-root user
USER node

# Set working directory to agent-catalog
WORKDIR /app/agent-catalog

# Expose ports
EXPOSE 4004 8080 4040

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:4004/health || exit 1

# Default command
CMD ["bash"]
