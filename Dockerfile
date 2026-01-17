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
# Stage 2: Rust Backend Build
# ============================================
FROM rust:1.83-slim AS rust-builder

WORKDIR /app

# Install dependencies for building
RUN apt-get update && apt-get install -y pkg-config && rm -rf /var/lib/apt/lists/*

# Copy Cargo workspace files
COPY Cargo.toml ./
COPY rust-backend ./rust-backend
COPY web-server ./web-server

# Create dummy src-tauri to satisfy workspace
RUN mkdir -p src-tauri/src && \
    echo '[package]\nname = "school-payment"\nversion = "0.1.0"\nedition = "2021"\n\n[lib]\nname = "school_payment_lib"\ncrate-type = ["lib"]\n\n[[bin]]\nname = "school-payment"\npath = "src/main.rs"' > src-tauri/Cargo.toml && \
    echo 'pub fn run() {}' > src-tauri/src/lib.rs && \
    echo 'fn main() {}' > src-tauri/src/main.rs

# Build web-server
RUN cargo build --release --package web-server

# ============================================
# Stage 3: Frontend Build
# ============================================
FROM node:20-slim AS frontend-builder

WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci

COPY frontend ./
RUN npm run build

# ============================================
# Stage 4: Production Runtime
# ============================================
FROM debian:bookworm-slim AS production

# Install runtime dependencies
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Lean advisor binary
COPY --from=lean-builder /app/lean-backend/.lake/build/bin/advisor /app/lean-backend/.lake/build/bin/advisor

# Copy Rust web-server binary
COPY --from=rust-builder /app/target/release/web-server /app/web-server

# Copy frontend static files
COPY --from=frontend-builder /app/frontend/dist /app/frontend/dist

# Install serve for static file serving
RUN apt-get update && apt-get install -y nodejs npm && npm install -g serve && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 3001 5173

ENV LEAN_BACKEND_PATH=/app/lean-backend
ENV RUST_LOG=info

CMD ["/app/docker-entrypoint.sh"]
