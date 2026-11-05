ARG DEBIAN_VERSION=trixie
ARG DETOXIFY_VERSION=0.5.4
ARG FLASK_VERSION=3.1.3
ARG PYTHON_VERSION=3.15
ARG TORCH_VERSION=2.15.0
ARG GUNICORN_VERSION=26.2.0
ARG BUILDPLATFORM=linux/amd64

# ==========================================
# STAGE 1: Builder
# ==========================================
FROM --platform=$BUILDPLATFORM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION} AS builder

ARG DETOXIFY_VERSION
ARG FLASK_VERSION
ARG TORCH_VERSION
ARG GUNICORN_VERSION

ENV TORCH_HOME=/models/torch \
    HF_HOME=/models/huggingface

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    curl \
    git \
    libssl-dev \
    pkg-config

RUN curl https://sh.rustup.rs -sSf | sh -s -- --profile minimal --default-toolchain stable -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --upgrade pip --no-cache-dir \
    && pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu \
        detoxify==$DETOXIFY_VERSION \
        flask==$FLASK_VERSION \
        torch==$TORCH_VERSION \
        gunicorn==$GUNICORN_VERSION

RUN echo "Warming up multilingual" \
    && python -c "from detoxify import Detoxify; Detoxify('multilingual').predict('Hello world!')" \
    && echo "Warming up original-small" \
    && python -c "from detoxify import Detoxify; Detoxify('original-small').predict('Hello world!')" \
    && echo "Warming up original" \
    && python -c "from detoxify import Detoxify; Detoxify('original').predict('Hello world!')"

# ==========================================
# STAGE 2: Final Runtime
# ==========================================
FROM --platform=$BUILDPLATFORM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION}

ENV PATH="/opt/venv/bin:$PATH" \
    TORCH_HOME=/models/torch \
    HF_HOME=/models/huggingface \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /models /models

COPY rootfs /

# Uses Gunicorn instead of Flask's dev server.
# Assumes entrypoint.py contains your Flask instance named 'app'.
ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:80", "--workers", "2", "--timeout", "120", "entrypoint:app"]

STOPSIGNAL SIGINT

EXPOSE 80
