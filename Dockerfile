# Base container
FROM docker.io/library/python:3.13-alpine3.20@sha256:c38ead8bcf521573dad837d7ecfdebbc87792202e89953ba8b2b83a9c5a520b6 AS base

RUN --mount=target=/var/cache/apk,type=cache,sharing=locked --mount=target=/root/.cache/pip,type=cache,sharing=locked \
  apk update \
  && apk add \
    gcc

# Build container
FROM base AS build

RUN --mount=target=/var/cache/apk,type=cache,sharing=locked --mount=target=/root/.cache/pip,type=cache,sharing=locked \
  apk update \
  && apk add \
    cargo \
    libffi-dev \
    linux-headers \
    musl-dev \
    python3-dev \
    rust \
  && python3 -m ensurepip \
  && python3 -m pip install \
    --root-user-action ignore \
    --upgrade \
    pip \
    setuptools \
    wheel

RUN python3 -m venv /venv
ENV PATH=/venv/bin:$PATH

COPY requirements.txt .
RUN --mount=target=/root/.cache/pip,type=cache,sharing=locked \
  python3 -m pip install \
    --requirement requirements.txt \
    --root-user-action ignore

# Output container
FROM base

ARG VERSION
ENV VERSION=${VERSION}

RUN adduser \
    --disabled-password \
    --home /app \
    appuser \
  && chown -R appuser:appuser /app

USER appuser

COPY --from=build /venv /venv
ENV PATH=/venv/bin:$PATH

COPY --chown=appuser:appuser /app /app

CMD ["sh", "-c", "gunicorn app.main:api --bind 0.0.0.0:8080 --proxy-protocol --workers 4 --worker-class uvicorn.workers.UvicornWorker"]
