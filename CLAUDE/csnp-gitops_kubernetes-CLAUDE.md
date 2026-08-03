# CSNP GitOps K8s — Codebase Reference

## Overview

Kubernetes GitOps deployment for the CSNP (Core Services Network Platform) fintech system. Manages DEV and UAT environments across 7 sub-repos using **Kustomize** (base + overlay) and **ArgoCD** (App-of-Apps pattern). Monitoring is now managed from a dedicated `csnp-gitops-monitoring` repo rather than being authored inline under `csnp-gitops-root`.

---

## Repository Layout

This workspace is a parent directory containing 7 independently cloned git repos (not submodules — each is listed in the top-level `.gitignore`):

```
d:\CSNP\GitOps\csnp-gitops_kubernetes/
├── csnp-gitops-root/        # Cluster bootstrap: namespaces, NetworkPolicies, monitoring
├── csnp-gitops-monitoring/  # Observability: Prometheus + Grafana
├── csnp-gitops-platform/    # Platform services: credential, notification, zor-presentation
├── csnp-gitops-fintech/     # Fintech services: payment, wallet, trading, ledger, payout
├── csnp-gitops-compliance/  # Compliance services: api-compliance, consumer-compliance
├── csnp-gitops-web/         # Frontend: ui-web (Next.js)
└── csnp-gitops-admin/       # Frontend: ui-admin (Angular)
```

### Sub-repo structure (platform, fintech, compliance, web, admin)

```
<sub-repo>/
├── base/<service>/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
├── apps/
│   ├── apps-root-dev.yaml          # ArgoCD root Application for DEV
│   ├── apps-root-uat.yaml          # ArgoCD root Application for UAT
│   ├── dev/
│   │   ├── _root/                  # Per-service ArgoCD Application manifests
│   │   └── <service>/              # Kustomize DEV overlay
│   │       ├── kustomization.yaml
│   │       ├── env-patch.yaml
│   │       ├── ingress-patch.yaml
│   │       └── replica-patch.yaml  # workers only
│   └── uat/                        # Mirror of dev/ with UAT-specific values
└── README.md
```

### csnp-gitops-root structure

```
csnp-gitops-root/
└── clusters/dev/
    ├── namespace/csnp-dev/         # Namespace + NetworkPolicies
    └── monitoring/                 # ArgoCD handoff to csnp-gitops-monitoring
```

### csnp-gitops-monitoring structure

```
csnp-gitops-monitoring/
├── apps/
│   ├── apps-root-dev.yaml          # ArgoCD root Application for DEV monitoring
│   └── dev/
│       ├── _root/
│       │   └── application_monitoring.yaml
│       └── monitoring/             # Kustomize monitoring stack
└── config/                         # Source-of-truth config mounted via ConfigMaps
```

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Orchestration | Kubernetes |
| Config management | Kustomize (base + overlays) |
| GitOps controller | ArgoCD |
| Ingress controller | ingress-nginx |
| Secret management | Hashicorp Vault (platform) / plaintext overlay (fintech) |
| Monitoring | Dedicated repo: Prometheus, Grafana, Alertmanager, Loki, Promtail, Tempo, OpenTelemetry Collector |
| APIs / Workers | .NET Core / C# (`ASPNETCORE_ENVIRONMENT=Production`) |
| Frontend | Next.js (ui-web, ui-admin), Nginx SPA (zor-presentation) |
| Auth | Keycloak (external, `idp-dev.csnp.xyz`) |
| Message Queue | RabbitMQ (external, `docker-dev.csnp.xyz`) |
| Database | PostgreSQL (external, `docker-dev.csnp.xyz`, port 5432) |
| Cache | Redis (external, payment/payout/wallet only) |
| Object Storage | MinIO (external, worker-notification only) |
| Payments | Stripe, PayPal (external) |
| Image registry | Harbor (`harbor-dev.csnp.xyz`) |

---

## Services

### Platform (`csnp-gitops-platform`)

| Service | Type | Container Port | K8s Service Ports |
|---------|------|---------------|-------------------|
| api-credential | .NET API | 8080 | 80 (HTTP), 81→8081 (gRPC) |
| api-mobilebff | .NET API | 8080 | 80 (HTTP) |
| api-notification | .NET API | 8080 | 80 (HTTP), 81→8081 (gRPC) |
| worker-notification | .NET Worker | 8080 | 80 (HTTP) |
| zor-presentation | Nginx SPA | 80 | 80 |

Platform services use **Vault Agent sidecar injection** for secrets and have dedicated `ServiceAccount` resources.

### Fintech (`csnp-gitops-fintech`)

| Service | Type | Redis |
|---------|------|-------|
| api-ledger | .NET API | No |
| api-payment | .NET API + Stripe/PayPal | Yes |
| api-payout | .NET API | Yes |
| api-trading | .NET API | No |
| api-wallet | .NET API | Yes |
| consumer-wallet | .NET Worker | Yes |
| worker-ledger | .NET Worker | No |
| worker-payment | .NET Worker | Yes |
| worker-payout | .NET Worker | No |
| worker-trading | .NET Worker | No |
| worker-wallet | .NET Worker | No |

All fintech services expose container port 8080; K8s Services expose port 80 (HTTP) and 81→8081 (gRPC) for APIs; workers expose port 80 only.

### Compliance (`csnp-gitops-compliance`)

| Service | Type | Container Port |
|---------|------|---------------|
| api-compliance | API | 8080 |
| consumer-compliance | Worker | 8080 |

Compliance services are managed from a dedicated compliance repo with its own `apps-root-dev` / `apps-root-uat` ArgoCD roots and per-service overlays.

### Web / Admin

| Service | Type | Container Port |
|---------|------|---------------|
| ui-web | Next.js | 3000 |
| ui-admin | Angular | 4200 |

### Monitoring (`csnp-gitops-monitoring`)

| Component | Workload | Purpose |
|-----------|----------|---------|
| grafana | Deployment | Dashboards, datasources, alerting contact points |
| prometheus | Deployment | Metrics scrape + alert rule evaluation |
| alertmanager | Deployment | Alert routing/notification delivery |
| loki | Deployment | Log aggregation |
| promtail | DaemonSet | Node log shipping to Loki |
| tempo | Deployment | Trace storage/query |
| otel-collector | Deployment | OTLP trace ingestion/export |

- Config is stored in `csnp-gitops-monitoring/config/` and generated into `ConfigMap`s/`Secret`s by Kustomize
- Grafana provisions datasources, dashboards, and alerting contact points from files in `config/grafana/provisioning/`
- Prometheus loads alert rules from `config/alerts/csnp-alerts.yaml` and sends alerts to standalone Alertmanager
- Public ingress is exposed for Grafana and Prometheus in the `monitoring` namespace

**Total per environment: 27 workloads** (5 platform + 11 fintech + 2 compliance + 2 web/admin + 7 monitoring, including 1 DaemonSet).

---

## Cluster Layout

### Namespaces

| Namespace | Purpose |
|-----------|---------|
| `csnp-dev` | All DEV workloads |
| `csnp-uat` | All UAT workloads |
| `monitoring` | Dedicated observability stack |
| `argocd` | ArgoCD controller (pre-existing) |
| `ingress-nginx` | NGINX ingress controller (pre-existing) |
| `kube-system` | metrics-server (pre-existing) |

### ArgoCD Projects

- `csnp-dev` — all DEV service Applications
- `csnp-uat` — all UAT service Applications
- `default` — bootstrap/cluster-level Applications

### Git Branch Strategy

| Branch | Purpose |
|--------|---------|
| `ops` | Cluster bootstrap (namespaces, NetworkPolicies, monitoring) — watched by ArgoCD root apps |
| `dev` | DEV overlays for all service sub-repos |
| `uat` | UAT overlays for all service sub-repos |

---

## Kustomize Pattern

### Base

`base/<service>/` defines environment-agnostic K8s resources:
- `deployment.yaml` — placeholder image `harbor-dev.csnp.xyz/placeholder`, resource limits, log volume mount
- `service.yaml` — ClusterIP service
- `ingress.yaml` — placeholder hostname, empty TLS, nginx rewrite annotations
- `kustomization.yaml` — lists the above three files

### Overlay (`apps/dev/<service>/kustomization.yaml`)

```yaml
resources:
  - ../../../base/<service>
  - serviceaccount.yaml    # platform only

namePrefix: csnp-dev-
namespace: csnp-dev

labels:
  - pairs:
      env: csnp-dev
    includeSelectors: true

images:
  - name: harbor-dev.csnp.xyz/placeholder
    newName: harbor-dev.csnp.xyz/csnp-dev/api-payment
    newTag: "dev-1"

patches:
  - path: ingress-patch.yaml    # JSON6902: set real hostname + TLS secret

patchesStrategicMerge:
  - env-patch.yaml              # sets all env vars and (platform) Vault annotations
  - replica-patch.yaml          # workers only

secretGenerator:                # frontends only
  - name: <service>-secret
    literals:
      - NEXTAUTH_SECRET=...
      - KEYCLOAK_CLIENT_SECRET=...
```

### Key overlay behaviors

- `namePrefix` namespaces all resource names (e.g., `api-payment` → `csnp-dev-api-payment`)
- Ingress patches set the real hostname and reference the `csnp-wildcard-tls` TLS secret
- Image tags are manually pinned per overlay (no automated tag update from CI)
- All `.NET` containers set `ASPNETCORE_ENVIRONMENT=Production`
- All Deployments reference `imagePullSecrets: [{name: harbor-creds}]`
- All `.NET` containers mount `logs-volume` (`emptyDir`) at `/app/logs`

---

## Ingress

**Controller**: `ingress-nginx` (`ingressClassName: nginx`)  
**TLS**: wildcard secret `csnp-wildcard-tls` in each namespace

Common API ingress annotations:
```yaml
nginx.ingress.kubernetes.io/rewrite-target: /$2
nginx.ingress.kubernetes.io/use-regex: "true"
nginx.ingress.kubernetes.io/ssl-redirect: "false"
nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
```

Path pattern `/payment(/|$)(.*)` strips the service prefix before forwarding.

### DEV Routing (`api-dev.csnp.xyz`)

| Path Pattern | Backend Service |
|-------------|-----------------|
| `/credential(/\|$)(.*)` | `csnp-dev-api-credential:80` |
| `/notification(/\|$)(.*)` | `csnp-dev-api-notification:80` |
| `/compliance(/\|$)(.*)` | `csnp-dev-api-compliance:80` |
| `/payment(/\|$)(.*)` | `csnp-dev-api-payment:80` |
| `/wallet(/\|$)(.*)` | `csnp-dev-api-wallet:80` |
| `/trading(/\|$)(.*)` | `csnp-dev-api-trading:80` |
| `/ledger(/\|$)(.*)` | `csnp-dev-api-ledger:80` |
| `/payout(/\|$)(.*)` | `csnp-dev-api-payout:80` |

| Host | Backend |
|------|---------|
| `dev.csnp.xyz` | `csnp-dev-ui-web:80` |
| `admin-dev.csnp.xyz` | `csnp-dev-ui-admin:80` |
| `zor-dev.csnp.xyz` | `csnp-dev-zor-presentation:80` |
| `worker-dev.csnp.xyz /notification` | `csnp-dev-worker-notification:80` |
| `worker-dev.csnp.xyz /payment` | `csnp-dev-worker-payment:80` |
| `grafana.csnp.xyz` | `csnp-monitoring-grafana:80` |
| `prometheus.csnp.xyz` | `csnp-monitoring-prometheus:9090` |

UAT mirrors this with `api-uat.csnp.xyz`, `uat.csnp.xyz`, `admin-uat.csnp.xyz`, etc.

---

## ArgoCD App-of-Apps

### Hierarchy

```
[Bootstrapped manually]
  ├── csnp-namespace-security-dev     # watches ops → clusters/dev/namespace/csnp-dev/
  ├── monitoring-stack                # watches ops → clusters/dev/monitoring/ (handoff app)
  ├── metrics-server                  # Helm chart (kubernetes-sigs, v3.13.0)
  ├── csnp-monitoring-root-dev        # watches kubernetes → csnp-gitops-monitoring/apps/dev/_root/
  │     └── csnp-monitoring-dev
  ├── csnp-compliance-root-dev        # watches dev → csnp-gitops-compliance/apps/dev/_root/  (recurse)
  │     ├── csnp-api-compliance-dev
  │     └── csnp-consumer-compliance-dev
  ├── csnp-platform-root-dev          # watches dev → apps/dev/_root/  (recurse)
  │     ├── csnp-api-credential-dev
  │     ├── csnp-api-notification-dev
  │     ├── csnp-worker-notification-dev
  │     └── csnp-zor-presentation-dev
  ├── csnp-fintech-root-dev           # watches dev → apps/dev/_root/  (recurse)
  │     └── csnp-api-{ledger,payment,payout,trading,wallet}-dev
  │         csnp-worker-{ledger,payment,payout,trading,wallet}-dev
  ├── csnp-web-root-dev               # watches dev → apps/dev/_root/
  │     └── csnp-ui-web-dev
  └── csnp-admin-root-dev             # watches dev → apps/dev/_root/
        └── csnp-ui-admin-dev
```

UAT mirrors the above (`*-uat` names, `uat` branch).

### Sync Policy

| Environment | Automated sync | prune | selfHeal |
|-------------|---------------|-------|---------|
| DEV | Yes | Yes | Yes |
| UAT | No (manual) | — | — |

DEV deploys automatically on any push to the `dev` branch. UAT requires a manual ArgoCD sync — acting as a promotion gate.

### Bootstrap commands (first time)

```bash
# Create monitoring namespace if needed
kubectl create namespace monitoring

# Create Grafana admin secret if not managed by GitOps yet
kubectl create secret generic csnp-monitoring-grafana-admin \
  -n monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=<value>

# Create Telegram secret if not managed by GitOps yet
kubectl create secret generic csnp-monitoring-telegram \
  -n monitoring \
  --from-literal=bot-token=<value> \
  --from-literal=chat-id=<value>
```

---

## Configuration Patterns

### Environment Variable Naming

All .NET services use hierarchical double-underscore naming:

```
LOC_<SERVICE>_<CATEGORY>__<PROPERTY>

Examples:
  LOC_CREDENTIAL_DATABASE__HOST
  LOC_PAYMENT_RABBITMQ__PORT
  LOC_WALLET_KEYCLOAK__CLIENTSECRET
  LOC_TRADING_REDIS__HOST
```

Categories: `DATABASE__*`, `RABBITMQ__*`, `REDIS__*`, `KEYCLOAK__*`, `MINIO__*`, `EMAIL__*`, `PAYPAL__*`, `STRIPE__*`, `CORS__ALLOWEDORIGINS`, `DOCUMENTATION__*`

### Secret Management

| Service group | Strategy |
|--------------|---------|
| Platform APIs/workers | **Vault Agent sidecar injection** — secrets injected as env vars at pod startup; never stored in K8s Secrets or Git |
| Fintech APIs/workers | **Plaintext in `env-patch.yaml`** — passwords committed to Git (known security gap) |
| Frontends (ui-web, ui-admin) | **`secretGenerator`** — Kustomize creates K8s Secrets from literals in `kustomization.yaml` |
| zor-presentation | **`configMapGenerator`** — `appsettings.Production.json` mounted into the Nginx container |

#### Vault pattern (platform services)

Vault paths: `secret/data/<service>/<env>` (e.g., `secret/data/api-credential/dev`)

```yaml
# env-patch.yaml annotations
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "api-credential"
vault.hashicorp.com/tls-skip-verify: "true"
vault.hashicorp.com/agent-inject-secret-LOC_CREDENTIAL_RABBITMQ__PASSWORD: "secret/data/api-credential/dev"
vault.hashicorp.com/agent-inject-template-LOC_CREDENTIAL_RABBITMQ__PASSWORD: |
  {{- with secret "secret/data/api-credential/dev" -}}
  {{ .Data.data.LOC_CREDENTIAL_RABBITMQ__PASSWORD }}
  {{- end }}
```

Each platform service has a dedicated `ServiceAccount` (`<prefix>-api-credential-sa`) for Vault Kubernetes auth.

### DEV vs UAT Differences

| Aspect | DEV | UAT |
|--------|-----|-----|
| Namespace | `csnp-dev` | `csnp-uat` |
| namePrefix | `csnp-dev-` | `csnp-uat-` |
| ArgoCD project | `csnp-dev` | `csnp-uat` |
| Hosts | `*.dev.csnp.xyz` | `*.uat.csnp.xyz` |
| DB | `dev_csnp`, user `dev` | `uat_csnp`, user `uat` |
| RabbitMQ | vhost `devvh` | vhost `uatvh` |
| Keycloak realm | `csnp-dev` | `csnp-uat` |
| CORS | includes `localhost:3000` | no localhost |
| ArgoCD auto-sync | yes | no (manual) |

---

## Resource Limits

| Workload type | CPU request | CPU limit | Memory request | Memory limit |
|--------------|------------|-----------|---------------|--------------|
| .NET APIs / Workers | 50m | 500m | 64Mi | 512Mi |
| Frontends (ui-web, ui-admin, zor-presentation) | 100m | 500m | 128Mi | 512Mi |

All deployments: `replicas: 1` in base.

---

## Network Policies (`csnp-dev` namespace)

| Policy | Effect |
|--------|--------|
| `default-deny-all` | Blocks all ingress + egress by default |
| `allow-dns` | Allows egress to `kube-system` on UDP/TCP 53 |
| `allow-external-infra` | Allows egress to `10.10.1.111` (docker-dev.csnp.xyz) on TCP 5432 (PostgreSQL) and TCP 5672 (RabbitMQ) |
| `allow-from-ingress` | Allows ingress from pods in `ingress-nginx` namespace |

NetworkPolicies are defined only for `csnp-dev`; no UAT NetworkPolicies exist in this repo yet.

---

## Monitoring

**Dedicated monitoring stack** in `monitoring` namespace:

- **Grafana**: file-provisioned datasources for Prometheus, Loki, and Tempo; dashboards from `config/grafana/dashboards/`; alerting contact points provisioned from file
- **Prometheus**: loads `config/prometheus-pro.yml`, evaluates `config/alerts/csnp-alerts.yaml`, and forwards alerts to standalone Alertmanager
- **Alertmanager**: standalone deployment configured from `config/alertmanager/alertmanager.yml`
- **Loki + Promtail**: centralized log collection pipeline
- **Tempo + otel-collector**: trace ingestion and storage path for OTLP traffic
- **Ingress**: `grafana.csnp.xyz` and `prometheus.csnp.xyz` are exposed from the monitoring repo manifests

---

## External Dependencies

All external services run on `docker-dev.csnp.xyz` (`10.10.1.111`):

| Service | Port | DEV resource | UAT resource |
|---------|------|-------------|-------------|
| PostgreSQL | 5432 | DB `dev_csnp` | DB `uat_csnp` |
| RabbitMQ | 5672 | vhost `devvh` | vhost `uatvh` |
| Redis | — | db 0 | db 0 |
| Keycloak | 443 | realm `csnp-dev` | realm `csnp-uat` |
| MinIO | — | worker-notification only | — |

---

## Common Operations

```bash
# Check ArgoCD sync status
kubectl get applications -n argocd

# Force-sync a DEV service
argocd app sync csnp-api-payment-dev

# Manually sync UAT (promotion gate)
argocd app sync csnp-api-payment-uat

# View logs for a service
kubectl logs -n csnp-dev -l app=csnp-dev-api-payment --tail=100 -f

# Health check via ingress
curl -H "Host: api-dev.csnp.xyz" https://api-dev.csnp.xyz/credential/health

# Update image tag for a service (then push to dev branch — ArgoCD auto-syncs)
# Edit apps/dev/<service>/kustomization.yaml → images[].newTag
```

---

## Git Remotes

| Sub-repo | Remote |
|----------|--------|
| csnp-gitops-root | `git@github.com:skg-csnp/csnp-gitops-root.git` |
| csnp-gitops-monitoring | `git@github.com:skg-csnp/csnp-gitops-monitoring.git` |
| csnp-gitops-platform | `git@github.com:skg-csnp/csnp-gitops-platform.git` |
| csnp-gitops-fintech | `git@github.com:skg-csnp/csnp-gitops-fintech.git` |
| csnp-gitops-compliance | `git@github.com:skg-csnp/csnp-gitops-compliance.git` |
| csnp-gitops-web | `git@github.com:skg-csnp/csnp-gitops-web.git` |
| csnp-gitops-admin | `git@github.com:skg-csnp/csnp-gitops-admin.git` |

Branch: `ops` (cluster bootstrap), `dev` / `uat` (service overlays)

---

## Key Design Decisions

1. **App-of-Apps ArgoCD** — one root Application per sub-repo per environment watches `_root/`; `_root/` contains per-service Application manifests; monitoring now follows the same dedicated-repo pattern instead of living inline in `csnp-gitops-root`
2. **Kustomize base + env overlays** — base is abstract (placeholder image, placeholder hostname); overlays add real image tag, hostname, TLS ref, all env vars, and optionally Vault annotations
3. **DEV auto-sync, UAT manual** — any push to `dev` branch triggers immediate deployment; UAT promotion requires explicit ArgoCD sync
4. **Single namespace per environment** — all 20 services share `csnp-dev` / `csnp-uat`; differentiated by `csnp-dev-` namePrefix and `env: csnp-dev` labels
5. **Wildcard TLS** — single `csnp-wildcard-tls` Secret covers all `*.csnp.xyz` hostnames per namespace
6. **Mixed secret strategy** — platform uses Vault (secure); fintech uses plaintext env-patches (security gap to address)
7. **Inter-service HTTP via ingress** — services call each other through the public ingress URL (e.g., `api-payment` → `https://api-dev.csnp.xyz/wallet/`), not via ClusterIP
8. **No CI pipeline in this repo** — image tags are updated manually in overlay `kustomization.yaml` files; no automated tag promotion from a build pipeline
