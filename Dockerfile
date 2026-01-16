# ============================================
# Stage 1: Lean4 Backend Build
# ============================================
FROM ubuntu:22.04 AS lean-builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install elan (Lean version manager)
RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

# Copy Lean project
WORKDIR /app/lean-backend
COPY lean-backend/lean-toolchain lean-backend/lakefile.lean lean-backend/lakefile.toml* ./
COPY lean-backend/Main.lean ./
COPY lean-backend/src ./src

# Build Lean project
RUN lake update && lake build

# ============================================
# Stage 2: Node.js Build
# ============================================
FROM node:20-slim AS node-builder

WORKDIR /app

# Build API server
COPY api-server/package*.json ./api-server/
RUN cd api-server && npm ci

COPY api-server ./api-server
RUN cd api-server && npm run build

# Build Frontend
COPY frontend/package*.json ./frontend/
RUN cd frontend && npm ci

COPY frontend ./frontend
RUN cd frontend && npm run build

# ============================================
# Stage 3: Production Runtime
# ============================================
FROM ubuntu:22.04 AS production

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install newer Node.js
RUN npm install -g n && n 20 && npm install -g npm@latest

# Install elan for runtime
RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

WORKDIR /app

# Copy Lean backend (built)
COPY --from=lean-builder /app/lean-backend /app/lean-backend
COPY --from=lean-builder /root/.elan /root/.elan

# Copy Node.js apps (built)
COPY --from=node-builder /app/api-server/dist /app/api-server/dist
COPY --from=node-builder /app/api-server/package*.json /app/api-server/
COPY --from=node-builder /app/frontend/dist /app/frontend/dist

# Install production dependencies for API server
RUN cd /app/api-server && npm ci --production

# Install serve for static file hosting
RUN npm install -g serve

# Copy startup script
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

# Expose ports
EXPOSE 3001 5173

# Set environment
ENV NODE_ENV=production
ENV LEAN_BACKEND_PATH=/app/lean-backend

CMD ["/app/docker-entrypoint.sh"]

# ============================================
# Stage 4: Development
# ============================================
FROM ubuntu:22.04 AS development

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install elan (Lean version manager)
RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

# Install cargo-make
RUN curl -fsSL https://github.com/sagiegurari/cargo-make/releases/download/0.37.8/cargo-make-v0.37.8-x86_64-unknown-linux-musl.zip -o cargo-make.zip \
    && apt-get update && apt-get install -y unzip \
    && unzip cargo-make.zip \
    && mv cargo-make-v0.37.8-x86_64-unknown-linux-musl/makers /usr/local/bin/ \
    && rm -rf cargo-make.zip cargo-make-v0.37.8-x86_64-unknown-linux-musl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project files
COPY . .

# Install dependencies
RUN cd lean-backend && lake update
RUN cd api-server && npm install
RUN cd frontend && npm install

# Build Lean backend
RUN cd lean-backend && lake build

# Expose ports
EXPOSE 3001 5173

CMD ["makers", "dev"]
