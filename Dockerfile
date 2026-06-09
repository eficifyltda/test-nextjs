# syntax=docker/dockerfile:1

# Next.js 16 requer Node >= 20.9. Usamos a imagem Alpine para um runtime enxuto.
ARG NODE_VERSION=20-alpine

# 1. Instala dependências apenas quando necessário
FROM node:${NODE_VERSION} AS deps
# libc6-compat é recomendado para compatibilidade de binários no Alpine
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# 2. Build da aplicação
FROM node:${NODE_VERSION} AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Desativa telemetria durante o build
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# 3. Imagem final de produção — usa o output standalone
FROM node:${NODE_VERSION} AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Executa como usuário sem privilégios
RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs

# Assets públicos
COPY --from=builder /app/public ./public

# Saída standalone: inclui apenas os arquivos necessários para rodar o servidor
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# server.js é gerado pelo output standalone do Next.js
CMD ["node", "server.js"]
