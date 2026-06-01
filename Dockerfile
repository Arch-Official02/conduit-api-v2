# ── base image ────────────────────────────────────────────────────────────────
# We use Node 20 LTS on Alpine Linux. Alpine is a minimal Linux distro
# (~5MB vs ~200MB for Ubuntu). LTS means long-term support — stable for years.
FROM node:20-alpine

# ── working directory ─────────────────────────────────────────────────────────
# All subsequent commands run from this folder inside the container.
# If it doesn't exist, Docker creates it.
WORKDIR /app

# ── install dependencies ──────────────────────────────────────────────────────
# We copy package files FIRST, before copying app code.
# This is a critical optimization — Docker caches each step (called a layer).
# If only app code changes, Docker reuses the cached node_modules layer
# and skips npm install entirely. Saves minutes on every build.
COPY package*.json ./
RUN npm ci --omit=dev

# ── copy app source ───────────────────────────────────────────────────────────
# Now copy everything else. .dockerignore controls what gets excluded.
COPY . .

# ── runtime config ────────────────────────────────────────────────────────────
# Document which port the app listens on. Doesn't actually publish it —
# that happens in docker-compose.yml. Just metadata for humans and tools.
EXPOSE 3000

# ── start command ─────────────────────────────────────────────────────────────
# CMD is what runs when the container starts.
# Use array form (not string) — avoids shell interpretation issues.
CMD ["node", "app.js"]
