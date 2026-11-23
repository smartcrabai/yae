# Chef stage: cargo-chef is preinstalled
FROM lukemathwalker/cargo-chef:latest-rust-1.99@sha256:420b7375dc4059a85f1c365f23f96b8f561c2861e365645b413c531b206c528a AS chef

WORKDIR /app

# Planner stage: Prepare recipe.json
FROM chef AS planner

COPY . .

RUN cargo chef prepare --recipe-path recipe.json

# Builder stage: Build dependencies and application
FROM chef AS builder

# Install required dependencies
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

COPY --from=planner /app/recipe.json recipe.json

# Build dependencies (this layer will be cached)
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/app/target,sharing=locked \
    cargo chef cook --release --recipe-path recipe.json

# Copy source code and build application
COPY . .

RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,target=/app/target,sharing=locked \
    cargo build --release && \
    cp /app/target/release/yae /tmp/yae

# Runtime stage: Create minimal production image
FROM gcr.io/distroless/cc-debian13:nonroot@sha256:532c7a94f9e96ba9db75eb9388f4227751131c7cb0a411d1a8521af4096135de

WORKDIR /app

COPY --from=builder /tmp/yae .

CMD ["./yae"]
