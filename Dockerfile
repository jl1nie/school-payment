# ============================================
# Stage 1: Lean4 Backend Build
# ============================================
FROM ubuntu:22.04 AS lean-builder

RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

RUN curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

WORKDIR /app/lean-backend
COPY lean-backend/lean-toolchain lean-backend/lakefile.lean lean-backend/lakefile.toml* ./
COPY lean-backend/Main.lean ./
COPY lean-backend/src ./src

RUN lake update && lake build

# ============================================
# Stage 2: Node.js Build
# ============================================
FROM node:20-slim AS node-builder

WORKDIR /app

COPY api-server/package*.json ./api-server/
RUN cd api-server && npm ci
COPY api-server ./api-server
RUN cd api-server && npm run build

COPY frontend/package*.json ./frontend/
RUN cd frontend && npm ci
COPY frontend ./frontend
RUN cd frontend && npm run build

# ============================================
# Stage 3: Production Runtime
# ============================================
FROM node:20-slim AS production

WORKDIR /app

COPY --from=lean-builder /app/lean-backend/.lake/build/bin/advisor /app/lean-backend/.lake/build/bin/advisor

COPY --from=node-builder /app/api-server/dist /app/api-server/dist
COPY --from=node-builder /app/api-server/package*.json /app/api-server/
COPY --from=node-builder /app/frontend/dist /app/frontend/dist

RUN cd /app/api-server && npm ci --production
RUN npm install -g serve

COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 3001 5173

ENV NODE_ENV=production
ENV LEAN_BACKEND_PATH=/app/lean-backend

CMD ["/app/docker-entrypoint.sh"]
