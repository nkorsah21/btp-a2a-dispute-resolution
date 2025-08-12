# Use Node.js LTS version as base
FROM node:lts

# Set environment variables
ENV NPM_CONFIG_PREFIX=/home/node/.npm
ENV PATH=$NPM_CONFIG_PREFIX/bin:$PATH
ENV NODE_ENV=development

# Use pre-created non-root 'node' user to install global npm packages
USER node
RUN npm install -g @sap/cds-dk@7.0.0 ts-node

# Switch to root to install system dependencies
USER root

# Install system packages
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    git \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install ngrok
RUN curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null \
  && echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  > /etc/apt/sources.list.d/ngrok.list \
  && apt-get update \
  && apt-get install -y ngrok

# Set working directory
WORKDIR /app

# Copy source files into image
COPY . .

# Fix ownership for the app folder (important!)
RUN chown -R node:node /app

# Switch to node user for app dependency installation
USER node

# Install Node.js dependencies
RUN cd agent-catalog && npm install
RUN cd agents/sap-agent-builder-a2a/agent-builder-a2a-agent-connector && npm install

# Switch back to root for Python setup
USER root

# Setup Python venv and install requirements
RUN cd agents/gcp-adk-a2a && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

RUN cd agents/azure-ai-foundry-a2a && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

# Final permissions fix (for runtime)
RUN chown -R node:node /app

# Switch back to node user for runtime
USER node

# Set default working directory for interactive sessions
WORKDIR /app/agent-catalog

# Expose application and dev ports
EXPOSE 4004 8080 4040

# Health check to confirm service is up
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:4004/health || exit 1

# Default command opens bash (dev use)
CMD ["bash"]
