# trunk-ignore-all(hadolint/DL4006)
# trunk-ignore-all(checkov/CKV_DOCKER_3)
# trunk-ignore-all(hadolint/DL3008)

###########################################
# Base image used by builder and deployer
###########################################
FROM python:3.10.14-slim-bookworm as base

HEALTHCHECK NONE

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/app/kakarot/.venv \
    PATH="/app/kakarot/.venv/bin:/root/.local/bin:$PATH"

RUN --mount=type=cache,target=/root/.cache \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN --mount=type=cache,target=/root/.cache \
curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH="/root/.cargo/bin:$PATH"

WORKDIR /app/kakarot

############################################
# Kakarot builder
############################################
FROM base as builder

ENV PATH="$PATH:/root/.local/bin:/root/.foundry/bin"
RUN curl -L https://foundry.paradigm.xyz -o foundry.sh \
    && chmod +x foundry.sh \
    && ./foundry.sh \
    && foundryup

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    gcc \
    jq \
    libgmp-dev \
    python3-dev \
    tar \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=${GITHUB_TOKEN}

COPY . .
COPY .env.example .env

SHELL ["/bin/bash", "-c"]
RUN  source "$HOME/.cargo/env"

# Install asdf for multiple scarb versions
RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git "$HOME/.asdf" && \
    echo ". $HOME/.asdf/asdf.sh" >> "$HOME/.bashrc" && \
    echo ". $HOME/.asdf/asdf.sh" >> "$HOME/.profile"

RUN source "$HOME/.asdf/asdf.sh" && asdf plugin add scarb && asdf install scarb 0.7.0  && asdf install scarb 2.6.5 && asdf install scarb 2.8.3

RUN uv sync --all-extras --dev
RUN --mount=type=cache,target=/root/.cache \
    source "$HOME/.asdf/asdf.sh" && source "$HOME/.cargo/env" && make build && make build-sol


############################################
# Kakarot deployer
############################################
FROM base as deployer

COPY --from=builder /app/kakarot/build ./build/
COPY --from=builder /app/kakarot/kakarot_scripts/ ./kakarot_scripts/
COPY --from=builder /app/kakarot/tests ./tests/
COPY --from=builder /app/kakarot/.venv ./.venv

# Cairo Smart contracts are used in deploy_kakarot.py
# To limit the probability of this Dockerfile to break, we copy the entire src and not individual files
COPY --from=builder /app/kakarot/cairo_zero/ ./cairo_zero/
COPY --from=builder /app/kakarot/cairo/ ./cairo/

# Default Solidity contracts are also used in deploy_kakarot.py
COPY --from=builder /app/kakarot/solidity_contracts ./solidity_contracts/

COPY --from=builder /app/kakarot/Makefile .
COPY --from=builder /app/kakarot/uv.lock .
COPY --from=builder /app/kakarot/pyproject.toml .
COPY --from=builder /app/kakarot/foundry.toml .
COPY --from=builder /app/kakarot/README.md .
COPY --from=builder /app/kakarot/.env.example .env
COPY --from=builder /app/kakarot/conftest.py .
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

# Deploy kakarot
CMD ["uv", "run", "deploy"]
