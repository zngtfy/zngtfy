# CSNP GitOps K8s — Codebase Reference

## Overview

Kubernetes GitOps deployment for the CSNP (Credential Service Notification Platform) fintech system. Manages DEV and UAT environments across 5 sub-repos using **Kustomize** (base + overlay) and **ArgoCD** (App-of-Apps pattern). No Helm charts are authored here — Helm is used only for the monitoring stack via Kustomize's `HelmChartInflationGenerator`.

---

## Repository Layout

This workspace is a parent directory containing 5 independently cloned git repos (not submodules — each is listed in the top-level `.gitignore`):

```
d:\CSNP\GitOps\csnp-gitops_kubernetes/
├── csnp-gitops-root/        # Cluster bootstrap: namespaces, NetworkPolicies, monitoring
├── csnp-gitops-platform/    # Platform services: credential, notification, zor-presentation
├── csnp-gitops-fintech/     # Fintech services: payment, wallet, trading, ledger, compliance, payout
├── csnp-gitops-web/         # Frontend: ui-web (Next.js)
└── csnp-gitops-admin/       # Frontend: ui-admin (Angular)
```

### Sub-repo structure (platform, fintech, web, admin)

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
    └── monitoring/                 # kube-prometheus-stack via Helm
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
| Monitoring | kube-prometheus-stack v82.2.1 (Prometheus + Grafana + Alertmanager) |
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
| api-notification | .NET API | 8080 | 80 (HTTP), 81→8081 (gRPC) |
| worker-notification | .NET Worker | 8080 | 80 (HTTP) |
| zor-presentation | Nginx SPA | 80 | 80 |

Platform services use **Vault Agent sidecar injection** for secrets and have dedicated `ServiceAccount` resources.

### Fintech (`csnp-gitops-fintech`)

| Service | Type | Redis |
|---------|------|-------|
| api-compliance | .NET API | No |
| api-ledger | .NET API | No |
| api-payment | .NET API + Stripe/PayPal | Yes |
| api-payout | .NET API | Yes |
| api-trading | .NET API | No |
| api-wallet | .NET API | Yes |
| worker-compliance | .NET Worker | No |
| worker-ledger | .NET Worker | No |
| worker-payment | .NET Worker | Yes |
| worker-payout | .NET Worker | No |
| worker-trading | .NET Worker | No |
| worker-wallet | .NET Worker | No |

All fintech services expose container port 8080; K8s Services expose port 80 (HTTP) and 81→8081 (gRPC) for APIs; workers expose port 80 only.

### Web / Admin

| Service | Type | Container Port |
|---------|------|---------------|
| ui-web | Next.js | 3000 |
| ui-admin | Angular | 4200 |

**Total per environment: 20 Deployments** (4 platform + 12 fintech + 2 web/admin + monitoring excluded).

---

## Cluster Layout

### Namespaces

| Namespace | Purpose |
|-----------|---------|
| `csnp-dev` | All DEV workloads |
| `csnp-uat` | All UAT workloads |
| `monitoring` | kube-prometheus-stack |
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
| `grafana-dev.csnp.xyz` | `monitoring-grafana:80` |
| `prometheus-dev.csnp.xyz` | `monitoring-kube-prometheus-prometheus:9090` |

UAT mirrors this with `api-uat.csnp.xyz`, `uat.csnp.xyz`, `admin-uat.csnp.xyz`, etc.

---

## ArgoCD App-of-Apps

### Hierarchy

```
[Bootstrapped manually]
  ├── csnp-namespace-security-dev     # watches ops → clusters/dev/namespace/csnp-dev/
  ├── monitoring-stack                # watches ops → clusters/dev/monitoring/
  ├── metrics-server                  # Helm chart (kubernetes-sigs, v3.13.0)
  ├── csnp-platform-root-dev          # watches dev → apps/dev/_root/  (recurse)
  │     ├── csnp-api-credential-dev
  │     ├── csnp-api-notification-dev
  │     ├── csnp-worker-notification-dev
  │     └── csnp-zor-presentation-dev
  ├── csnp-fintech-root-dev           # watches dev → apps/dev/_root/  (recurse)
  │     └── csnp-api-{compliance,ledger,payment,payout,trading,wallet}-dev
  │         csnp-worker-{compliance,ledger,payment,payout,trading,wallet}-dev
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
# Enable Helm support in ArgoCD's Kustomize
kubectl patch configmap argocd-cm -n argocd \
  --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}' \
  && kubectl rollout restart deploy argocd-repo-server -n argocd

# Create monitoring namespace + Grafana OAuth secret
kubectl create namespace monitoring
kubectl create secret generic grafana-oauth-secret \
  -n monitoring \
  --from-literal=client-secret=<value>
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

**kube-prometheus-stack v82.2.1** in `monitoring` namespace:

- **Grafana**: OAuth via Keycloak (`idp-dev.csnp.xyz/realms/csnp-dev`); roles `grafana-admin`/`grafana-editor` mapped to Grafana roles
- **Prometheus**: scrapes all namespaces (`serviceMonitorNamespaceSelector.any: true`), 7-day retention
- **ServiceMonitors**: `api-credential` and `api-payment` are currently defined (pattern ready to extend)

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
| csnp-gitops-platform | `git@github.com:skg-csnp/csnp-gitops-platform.git` |
| csnp-gitops-fintech | `git@github.com:skg-csnp/csnp-gitops-fintech.git` |
| csnp-gitops-web | `git@github.com:skg-csnp/csnp-gitops-web.git` |
| csnp-gitops-admin | `git@github.com:skg-csnp/csnp-gitops-admin.git` |

Branch: `ops` (cluster bootstrap), `dev` / `uat` (service overlays)

---

## Key Design Decisions

1. **App-of-Apps ArgoCD** — one root Application per sub-repo per environment watches `_root/`; `_root/` contains per-service Application manifests; two-level hierarchy
2. **Kustomize base + env overlays** — base is abstract (placeholder image, placeholder hostname); overlays add real image tag, hostname, TLS ref, all env vars, and optionally Vault annotations
3. **DEV auto-sync, UAT manual** — any push to `dev` branch triggers immediate deployment; UAT promotion requires explicit ArgoCD sync
4. **Single namespace per environment** — all 20 services share `csnp-dev` / `csnp-uat`; differentiated by `csnp-dev-` namePrefix and `env: csnp-dev` labels
5. **Wildcard TLS** — single `csnp-wildcard-tls` Secret covers all `*.csnp.xyz` hostnames per namespace
6. **Mixed secret strategy** — platform uses Vault (secure); fintech uses plaintext env-patches (security gap to address)
7. **Inter-service HTTP via ingress** — services call each other through the public ingress URL (e.g., `api-payment` → `https://api-dev.csnp.xyz/wallet/`), not via ClusterIP
8. **No CI pipeline in this repo** — image tags are updated manually in overlay `kustomization.yaml` files; no automated tag promotion from a build pipeline
