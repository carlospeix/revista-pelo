# Stage 1: Build the Hugo site
FROM debian:bookworm-slim AS builder

ARG HUGO_VERSION=0.145.0
ARG HUGO_BASE_URL=https://www.revistapelo.com.ar/

WORKDIR /src

RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
    "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" | tar -xz -C /usr/local/bin hugo

COPY . .

RUN hugo --minify --baseURL "$HUGO_BASE_URL"

# Stage 2: Serve with nginx
FROM nginx:1.27-alpine

COPY --from=builder /src/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
