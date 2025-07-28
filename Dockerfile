# Use Node.js LTS version
FROM node:lts

# Use pre-created non-root 'node' user and configure npm global path
USER node
ENV NPM_CONFIG_PREFIX=/home/node/.npm
ENV PATH=$NPM_CONFIG_PREFIX/bin:$PATH
ENV NODE_ENV=development

# Install global Node.js dependencies as non-root user
RUN npm install -g @sap/cds-dk@7.0.0 ts-node

# Switch back to root to install system dependencies
USER root

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

# Install ngrok for development
RUN curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  > /etc/apt/sources.list.d/ngrok.list \
  && apt-get update \
  && apt-get install -y ngrok

# Set working directory
WORKDIR /app

# Copy package.json files first for better caching
COPY agent-catalog/package*.json ./agent-catalog/
COPY agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/package*.json ./agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector/
COPY agents/gcp-adk-a2a/requirements.txt ./agents/gcp-adk-a2a/
COPY agents/azure-ai-foundry-a2a/requirements.txt ./agents/azure-ai-foundry-a2a/

# Fix ownership so the 'node' user can write to these folders
RUN chown -R node:node /app/agent-catalog /app/agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector /app/agents/gcp-adk-a2a /app/agents/azure-ai-foundry-a2a

# Switch to node user to install npm packages
USER node

RUN cd agent-catalog && npm install
RUN cd agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector && npm install

# Switch back to root to install Python dependencies
USER root

RUN cd agents/gcp-adk-a2a && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

RUN cd agents/azure-ai-foundry-a2a && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application source code
COPY . .

# Fix ownership for the entire app folder to allow 'node' user access
RUN chown -R node:node /app

# Switch back to non-root user for runtime
USER node

# Set working directory to agent-catalog for running commands
WORKDIR /app/agent-catalog

# Expose necessary ports
EXPOSE 4004 8080 4040

# Healthcheck for the service
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:4004/health || exit 1

# Default command opens bash shell
CMD ["bash"]
