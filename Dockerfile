# ─────────────────────────────────────────────────────────────────────────────
# Dockerfile – Application Students (XYZ University)
# Base : Node.js 18 LTS Alpine (image legere ~180MB vs ~900MB pour node:18)
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1 : Installation des dependances ────────────────────────────────────
FROM node:18-alpine AS deps

WORKDIR /app

# Copier uniquement les fichiers de dependances pour profiter du cache Docker
COPY resources/codebase_partner/package*.json ./

# Installer uniquement les dependances de production
RUN npm ci --only=production && npm cache clean --force

# ── Stage 2 : Image finale ────────────────────────────────────────────────────
FROM node:18-alpine AS runner

# Metadonnees
LABEL maintainer="Universite Exemple"
LABEL version="2.0"
LABEL description="Application de gestion des dossiers etudiants – Phase 4"

WORKDIR /app

# Securite : creer un utilisateur non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser  -u 1001 -S nodeapp -G nodejs

# Copier les dependances depuis le stage deps
COPY --from=deps --chown=nodeapp:nodejs /app/node_modules ./node_modules

# Copier le code source
COPY --chown=nodeapp:nodejs resources/codebase_partner/ ./

# Variables d'environnement par defaut (surchargees au runtime)
ENV NODE_ENV=production \
    APP_PORT=80 \
    APP_DB_HOST="" \
    APP_DB_USER="" \
    APP_DB_PASSWORD="" \
    APP_DB_NAME="students"

# Exposer le port applicatif
EXPOSE 80

# Passer a l'utilisateur non-root
USER nodeapp

# Healthcheck – verifie que l'app repond
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:80/ || exit 1

# Demarrage
CMD ["node", "index.js"]
