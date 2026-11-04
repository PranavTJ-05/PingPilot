# syntax=docker/dockerfile:1.7

# ---- build stage ---------------------------------------------------------
FROM golang:1.25-alpine AS build
WORKDIR /src

# ca-certificates are required by the runtime, but pulling them here keeps
# the runtime stage minimal.
RUN apk add --no-cache ca-certificates git

# Cache module downloads in a separate layer so source-only changes don't
# re-pull dependencies.
COPY go.mod go.sum* ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .
ARG VERSION=dev
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/pingpilot-api ./cmd/api && \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/pingpilot-worker ./cmd/worker && \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/pingpilot-scheduler ./cmd/scheduler && \
    CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/pingpilot-migrate ./cmd/migrate && \
    ln -s /out/pingpilot-api /out/uptime-api && \
    ln -s /out/pingpilot-worker /out/uptime-worker && \
    ln -s /out/pingpilot-scheduler /out/uptime-scheduler && \
    ln -s /out/pingpilot-migrate /out/uptime-migrate

# ---- runtime stage -------------------------------------------------------
FROM alpine:3.20
WORKDIR /app

# Run as non-root with a known UID so PodSecurity / kubelet checks pass.
RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -S -g 65532 pingpilot && \
    adduser  -S -u 65532 -G pingpilot pingpilot

COPY --from=build /out/ /app/

USER 65532:65532
EXPOSE 8008 8009
ENV APP_PORT=8008 METRICS_PORT=8009
