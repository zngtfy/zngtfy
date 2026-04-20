# CSNP GitOps Docker — Codebase Reference

## Overview

Docker Compose-based microservices deployment for the CSNP (Credential Service Notification Platform) fintech system. Only nginx-ingress binds to the host (port 80 for DEV, port 81 for UAT); all microservices communicate exclusively over internal Docker bridge networks. Supports DEV and UAT environments using a base + overlay composition pattern.

---

## Repository Layout

```
d:\CSNP\GitOps\csnp-gitops_docker/
├── csnp-gitops-root/          # Nginx ingress + unified deploy scripts
├── csnp-gitops-platform/      # Platform services (Credential, Notification, MobileBFF)
├── csnp-gitops-fintech/       # Fintech services (Payment, Wallet, Trading, etc.)
├── csnp-gitops-compliance/    # Compliance services (api-compliance, consumer-compliance)
├── csnp-gitops-web/           # Frontend: ui-web (Next.js)
└── csnp-gitops-admin/         # Frontend: ui-admin (Angular)
```

Each repo uses the same structure:
```
compose/
  base/<service>/docker-compose.yaml    # Template (image, env vars, resources)
  dev/<service>/docker-compose.yaml     # DEV overlay (extends base, adds network/container name)
  uat/<service>/docker-compose.yaml     # UAT overlay
```

---

## Services

### Ingress (csnp-gitops-root)
- **nginx-ingress** — `nginx:1.27-alpine`; only container with host port `:80`; routes by hostname + path

### Platform (csnp-gitops-platform)
| Service | Type | Port (DEV) |
|---------|------|------------|
| api-credential | .NET API | HTTP 8080, gRPC 8081 |
| api-notification | .NET API | HTTP 8082, gRPC 8083 |
| api-mobilebff | .NET API | HTTP 8080 |
| worker-notification | .NET Worker | — |
| zor-presentation | Blazor WASM SPA (nginx) | 80 |

### Fintech (csnp-gitops-fintech)
| Service | Type | Port (DEV) |
|---------|------|------------|
| api-ledger | .NET API | 8080 |
| api-payment | .NET API | 8080 |
| api-payout | .NET API | 8080 |
| api-trading | .NET API | 8080 |
| api-wallet | .NET API | 8080 |
| consumer-wallet | .NET Worker | — |
| worker-{ledger,payment,payout,trading,wallet} | .NET Workers | — |

### Compliance (csnp-gitops-compliance)

| Service              | Type        | Port (DEV) |
|----------------------|-------------|------------|
| api-compliance       | Go API      | 8080       |
| consumer-compliance  | Go Worker   | —          |

### Web (csnp-gitops-web)
- **ui-web** — Next.js; port 3000

### Admin (csnp-gitops-admin)
- **ui-admin** — Angular SPA served by nginx; port 80
- Runtime config via bind-mounted `appsettings.Production.json` (gitignored, per-env)
- Image must include `RUN touch /usr/share/nginx/html/appsettings.Production.json` (Linux bind-mount requirement)

**Total**: ~22 containers per environment (10 APIs + 8 workers + 3 frontends + 1 ingress)

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Ingress | Nginx 1.27-alpine |
| APIs / Workers | .NET Core / C# |
| Frontend (web) | Next.js (Node.js) |
| Frontend (admin) | Angular (served by nginx) |
| Auth | Keycloak (external) |
| Message Queue | RabbitMQ (external) |
| Event Streaming | Kafka (external, compliance + consumer-wallet) |
| Database | SQL Server (external) |
| Document Store | MongoDB (external, compliance services only) |
| Cache | Redis (external, payment/payout/wallet/consumer-wallet only) |
| Object Storage | MinIO (external, worker-notification only) |
| Payments | Stripe, PayPal (external) |
| Orchestration | Docker Compose v2 |

---

## Networking

- **DEV network**: `csnp-dev` (bridge)
- **UAT network**: `csnp-uat` (bridge)
- All microservices have **no host port bindings** — internal only
- Requests flow: `Client → Edge Proxy (HTTPS) → Docker Host :80 → nginx-ingress → backend container`
- nginx uses Docker's embedded DNS resolver `127.0.0.11` so it starts even if backends are down

### Nginx Routing (DEV)

| Host | Path | Backend |
|------|------|---------|
| `api-dev.csnp.xyz` | `/credential/` | `csnp-dev-api-credential:8080` |
| `api-dev.csnp.xyz` | `/notification/` | `csnp-dev-api-notification:8080` |
| `api-dev.csnp.xyz` | `/mobilebff/` | `csnp-dev-api-mobilebff:8080` |
| `api-dev.csnp.xyz` | `/compliance/` | `csnp-dev-api-compliance:8080` |
| `api-dev.csnp.xyz` | `/payment/` | `csnp-dev-api-payment:8080` |
| `api-dev.csnp.xyz` | `/wallet/` | `csnp-dev-api-wallet:8080` |
| `api-dev.csnp.xyz` | `/trading/` | `csnp-dev-api-trading:8080` |
| `api-dev.csnp.xyz` | `/ledger/` | `csnp-dev-api-ledger:8080` |
| `api-dev.csnp.xyz` | `/payout/` | `csnp-dev-api-payout:8080` |
| `admin-dev.csnp.xyz` | `/` | `csnp-dev-ui-admin:80` |
| `zor-dev.csnp.xyz` | `/` | `csnp-dev-zor-presentation:80` |
| `dev.csnp.xyz` | `/` | `csnp-dev-ui-web:3000` |

### Nginx Routing (UAT)

| Host | Path | Backend |
|------|------|---------|
| `api-uat.csnp.xyz` | `/credential/` | `csnp-uat-api-credential:8080` |
| `api-uat.csnp.xyz` | `/notification/` | `csnp-uat-api-notification:8080` |
| `api-uat.csnp.xyz` | `/mobilebff/` | `csnp-uat-api-mobilebff:8080` |
| `api-uat.csnp.xyz` | `/compliance/` | `csnp-uat-api-compliance:8080` |
| `api-uat.csnp.xyz` | `/payment/` | `csnp-uat-api-payment:8080` |
| `api-uat.csnp.xyz` | `/wallet/` | `csnp-uat-api-wallet:8080` |
| `api-uat.csnp.xyz` | `/trading/` | `csnp-uat-api-trading:8080` |
| `api-uat.csnp.xyz` | `/ledger/` | `csnp-uat-api-ledger:8080` |
| `api-uat.csnp.xyz` | `/payout/` | `csnp-uat-api-payout:8080` |
| `admin-uat.csnp.xyz` | `/` | `csnp-uat-ui-admin:80` |
| `zor-uat.csnp.xyz` | `/` | `csnp-uat-zor-presentation:80` |
| `uat.csnp.xyz` | `/` | `csnp-uat-ui-web:3000` |

Path prefixes are stripped before forwarding (e.g., `/credential/foo` → `/foo`).

---

## Configuration Patterns

### Base + Overlay

- **base**: defines `image`, `environment`, `healthcheck`, `deploy` (resource limits), `volumes`
- **dev/uat overlay**: `extends` base, sets concrete `image: ${IMAGE_NAME}:${IMAGE_TAG}`, `container_name`, `networks`, `env_file`

### Environment Variable Naming

```
LOC_<SERVICE>_<CATEGORY>__<PROPERTY>

Examples:
  LOC_CREDENTIAL_DATABASE__HOST
  LOC_PAYMENT_RABBITMQ__PORT
  LOC_WALLET_KEYCLOAK__CLIENTSECRET
  LOC_TRADING_REDIS__HOST
  LOC_COMPLIANCE_KAFKA__BOOTSTRAPSERVERS
  LOC_COMPLIANCE_MONGO__URI
  LOC_MOBILEBFF_DOWNSTREAMSERVICES__CREDENTIAL
```

**Categories**: `DATABASE__*`, `RABBITMQ__*`, `REDIS__*`, `KEYCLOAK__*`, `KAFKA__*`, `MONGO__*`, `DOWNSTREAMSERVICES__*`, `HTTP__*`, `MINIO__*`, `EMAIL__*`, `PAYPAL__*`, `STRIPE__*`, `CORS__ALLOWEDORIGINS`

### Secrets (`.env` files)

- Located at `compose/<env>/<service>/.env` (NOT committed — gitignored via `compose/**/.env`)
- Loaded via `env_file:` in docker-compose overlay
- Each service has `.env.example` with placeholder values
- Key variables: `IMAGE_NAME`, `IMAGE_TAG`, DB password, RabbitMQ password, Keycloak secrets, API keys

### External Dependencies (not in compose)

All of the following run externally on `docker-dev.csnp.xyz`:
- SQL Server (database: `dev_csnp` / `uat_csnp`)
- RabbitMQ (vhost: `devvh` / `uatvh`)
- Redis
- Kafka (`kafka.csnp.xyz:9092`)
- MongoDB (port 27017; databases: `dev_csnp_compliance` / `uat_csnp_compliance`)
- Keycloak (at `https://idp-dev.csnp.xyz/realms/csnp-dev`)

---

## Resource Limits (All Containers)

| Component | Memory Limit | Memory Reserve | CPU Limit |
|-----------|-------------|----------------|-----------|
| APIs / Workers | 512MB | 64MB | 0.5 |
| ui-web / ui-admin | 512MB | 128MB | 0.5 |
| nginx-ingress | 512MB | 32MB | 0.5 |

Logging: `json-file`, max 10MB per file, 3 rotated files.

---

## Deployment

### Scripts

- `csnp-gitops-root/deploy-dev.sh` — deploys all services in correct order for DEV
- `csnp-gitops-root/deploy-uat.sh` — same for UAT
- Can target a single service: `bash deploy-dev.sh api-payment`

### First-Time Setup

1. Install Docker on Ubuntu 22.04/24.04 host
2. Clone all 6 repos directly into `~` (no subdirectory): root, platform, fintech, compliance, web, admin
3. Configure SSH multi-key for GitHub (`git@github-root-dev:`, `git@github-platform-dev:`, `git@github-compliance-dev:`, etc.)
4. Create `.registry.env` from `.registry.env.example` and fill in Harbor credentials
5. Copy `.env.example` → `.env` for each service and fill in secrets
6. Ensure public DNS `*.csnp.xyz` resolves to edge proxy (pfSense WAN IP); no local DNS override needed
7. Configure edge proxy: HTTPS→HTTP:80 (DEV) and HTTPS→HTTP:81 (UAT)
8. Run `cd ~ && bash csnp-gitops-root/deploy-dev.sh`

### Common Operations

```bash
# Deploy all (run from ~)
bash csnp-gitops-root/deploy-dev.sh

# Deploy single service
bash csnp-gitops-root/deploy-dev.sh api-payment

# Validate and hot-reload nginx (zero downtime)
docker compose -p csnp-dev-nginx exec nginx-ingress nginx -t
docker compose -p csnp-dev-nginx exec nginx-ingress nginx -s reload

# View logs
docker logs -f csnp-dev-api-payment --tail 100

# Health check
curl http://localhost/nginx-health
curl -H "Host: api-dev.csnp.xyz" http://localhost/credential/health

# Pull and restart a service
docker compose pull && docker compose up -d
```

---

## Health Checks

All services expose health endpoints used by Docker `healthcheck`:
- `.NET APIs`: `GET http://<container>:8080/health` (interval 30s, timeout 10s, start_period 20s)
- `ui-web`: `GET http://<container>:3000/`
- `nginx-ingress`: `GET http://localhost/nginx-health`

---

## Git Remotes (branch: `docker`)

| Repo | Remote |
|------|--------|
| csnp-gitops-root | `git@github-root-dev:skg-csnp/csnp-gitops-root.git` |
| csnp-gitops-platform | `git@github-platform-dev:skg-csnp/csnp-gitops-platform.git` |
| csnp-gitops-fintech | `git@github-fintech-dev:skg-csnp/csnp-gitops-fintech.git` |
| csnp-gitops-compliance | `git@github-compliance-dev:skg-csnp/csnp-gitops-compliance.git` |
| csnp-gitops-web | `git@github-web-dev:skg-csnp/csnp-gitops-web.git` |
| csnp-gitops-admin | `git@github-admin-dev:skg-csnp/csnp-gitops-admin.git` |

---

## Key Design Decisions

1. **Docker-native ingress** — eliminates Kubernetes while keeping zero exposed microservice ports
2. **Base + overlay composition** — DRY config; base is environment-agnostic, overlays add concrete values
3. **No persistent volumes** — logs only; data lives in external SQL Server / MongoDB
4. **Async communication via RabbitMQ** — APIs publish events, workers consume independently
5. **Kafka for compliance/wallet event streaming** — `consumer-wallet` and compliance services consume from Kafka topics instead of RabbitMQ
6. **Inter-service HTTP via edge proxy** — e.g., `api-mobilebff` calls `api-wallet` through `https://api-dev.csnp.xyz/wallet/`, not direct container-to-container
7. **Placeholder images in base** — `harbor-dev.csnp.xyz/placeholder:latest`; real tags injected via `.env` in overlays
