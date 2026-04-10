# ── Build stage ───────────────────────────────────────────────────────────────
FROM rust:1-slim-bookworm AS builder

# paho-mqtt uses the "bundled" feature which compiles the Paho C library from
# source, so cmake and a C/C++ compiler are required at build time.
RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        make \
        gcc \
        g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto
COPY src ./src

RUN cargo build --release

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/agv_vehicle_simulator ./

# Embed a default config.toml. Mount your own file over this path at runtime
# (see docker-compose.yml) to customise broker address, vehicle parameters, etc.
COPY config.toml ./

CMD ["./agv_vehicle_simulator"]
