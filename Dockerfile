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
    curl \
    git \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install global Node.js dependencies
RUN npm cache clean --force && \
    npm install -g @sap/cds-dk@7.0.0

# Install additional global Node.js tools (e.g., ts-node)
RUN npm install -g ts-node

# Set working directory
WORKDIR /app

# Copy package.json files first for better caching
COPY agent-catalog/package*.json ./agent-catalog/
COPY agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/package*.json ./agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/

# Copy Python requirements files
COPY agents/gcp-adk-a2a/requirements.txt ./agents/gcp-adk-a2a/
COPY agents/azure-ai-foundry-a2a/requirements.txt ./agents/azure-ai-foundry-a2a/

#install ngrok for development
RUN curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  > /etc/apt/sources.list.d/ngrok.list \
  && apt-get update \
  && apt-get install -y ngrok


# Install Node.js dependencies
RUN cd agent-catalog && npm ci
RUN cd agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector && npm ci

# Set up Python virtual environments and install dependencies
RUN cd agents/gcp-adk-a2a && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

RUN cd agents/azure-ai-foundry-a2a && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

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
