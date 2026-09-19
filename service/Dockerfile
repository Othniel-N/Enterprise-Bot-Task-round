FROM node:22.19.0-bookworm-slim AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev


FROM node:22.19.0-bookworm-slim

WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
COPY server.js ./

RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app

USER 10001

EXPOSE 8080

CMD ["node", "server.js"]