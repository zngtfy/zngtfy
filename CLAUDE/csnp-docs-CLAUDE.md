# CSNP Docs — Codebase Guide for Claude

## Project Overview

**`csnp-docs`** là **Documentation Hub trung tâm** của toàn bộ hệ sinh thái CSNP (Core Security Network Platform). Đây là một **documentation-only repository** — không chứa source code, không có CI/CD pipeline để build artifact. Mọi tài liệu đều là Markdown (`.md`) với YAML front-matter chuẩn.

**Mục tiêu repo:** Tập trung toàn bộ kiến thức kiến trúc, vận hành, quản trị, và onboarding vào một nơi duy nhất, phục vụ tất cả roles: Developer, Infrastructure Engineer, Platform Architect, Security/Compliance, Operator (SRE).

**Entry points:**
- `README.md` — Documentation Hub index (điều hướng toàn bộ)
- `START-HERE.md` — Role-based reading guide (đọc đầu tiên nếu mới vào)
- `knowledge/strategy/CSNP-Full-Execution-Roadmap.md` — Execution roadmap từ 0 đến production

---

## Repository Structure

```
csnp-docs/
├── README.md                    # Central navigation hub
├── START-HERE.md                # Role-based entry point (đọc đầu tiên)
├── CONTRIBUTING.md              # Quy tắc đóng góp tài liệu
├── architecture/                # Kiến trúc hệ thống (55 docs)
│   ├── CSNP-Platform-Big-Picture.md       # 10,000-foot overview toàn platform
│   ├── foundation/              # Kiến trúc nền tảng
│   ├── cicd/                    # CI/CD architecture & Jenkins standards
│   ├── decisions/               # Architecture Decision Records (ADR)
│   ├── operations/              # Reconciliation architecture
│   ├── platform/                # Control plane, security, runtime, observability
│   │   ├── control-plane/       # Control plane overview & service tier classification
│   │   ├── security/            # Identity, RBAC, secrets, trust model
│   │   ├── runtime/             # Kubernetes deployment contract, container versioning
│   │   ├── gitops/              # ArgoCD platform standard
│   │   ├── reliability/         # SLO, disaster recovery, reliability standards
│   │   └── developer-experience/# Application onboarding, service template, config management
│   ├── security/                # SSH trust domain, access path overview
│   └── services/                # Service-level architecture docs (Wallet, Payment, Payout, Ledger, Trading)
├── governance/                  # Quản trị & policy (17 docs)
│   ├── CSNP-Branching-Strategy.md
│   ├── CSNP-Change-Control.md
│   ├── CSNP-Environment-Promotion-Policy.md
│   ├── CSNP-Platform-Governance-Model.md
│   ├── compliance/              # ISO/IEC 27001, Zero Trust, SSH key lifecycle
│   └── policies/                # Backup policy
├── standards/                   # Engineering & platform standards (9 docs)
│   ├── backend/CSNP-Backend-Engineering-Rules.md
│   ├── documentation/CSNP-Documentation-Standard.md
│   ├── events/CSNP-Event-Contract-Standard.md
│   └── fintech/CSNP-Money-Safety-Standard.md
├── lifecycle/                   # Playbooks theo vòng đời platform (7 docs)
│   ├── infrastructure/CSNP-Day0-Infrastructure-Bootstrap-Playbook.md
│   ├── platform/CSNP-Day1-Platform-Bootstrap-Playbook.md
│   └── operations/CSNP-Day2-Platform-Operations-Playbook.md
├── operations/                  # Hướng dẫn vận hành chi tiết (72 docs)
│   ├── infrastructure/          # Hypervisor, base OS, provisioning, platform services
│   │   ├── base-os/             # Ubuntu 24.04 / Rocky 10 / Debian 13 golden templates
│   │   ├── hypervisor/          # Proxmox bare-metal installation
│   │   ├── platform-services/   # Jenkins, ArgoCD, Harbor, Keycloak, Vault, Edge Proxy
│   │   ├── identity/            # Keycloak RBAC, JWT validation, SSO
│   │   ├── access-and-keys/     # SSH keys, deploy keys, inventories
│   │   └── provisioning/        # VM cloning, post-clone provisioning
│   ├── network/                 # Network segmentation design, pfSense
│   ├── runbooks/                # Break-glass, key rotation, failure recovery
│   │   ├── jenkins/             # Jenkins CI agent disk full
│   │   ├── kubernetes/          # Kubernetes worker disk full
│   │   └── vault/               # Vault troubleshooting
│   └── procedures/              # Monitoring guide
├── guides/                      # Guides theo role (5 docs)
│   ├── developer/               # GitOps ArgoCD DEV guide
│   ├── operator/
│   └── onboarding/
├── knowledge/                   # Glossary, strategy, canonical knowledge (7 docs)
│   ├── glossary/CSNP-Glossary.md
│   ├── glossary/CSNP-Distributed-Glossary.md
│   └── strategy/CSNP-Full-Execution-Roadmap.md
├── learning/                    # Overview, FAQ, quickstart, troubleshooting (5 docs)
│   └── overview/CSNP-Enterprise-Overview.md
├── templates/                   # Reusable doc templates (8 docs)
│   ├── CSNP-Architecture-Overview-Template.md
│   ├── CSNP-Platform-Standard-Template.md
│   ├── CSNP-Implementation-Guide-Template.md
│   ├── CSNP-Playbook-Template.md
│   ├── CSNP-Runbook-Template.md
│   └── backend/CSNP-Service-Template.md
└── assets/                      # Diagrams and visual assets
```

---

## Document Format Standard

**Tất cả documents PHẢI có YAML front-matter:**

```yaml
---
title: <Document Title>
doc-type: Architecture Overview | Platform Standard | Policy | Playbook | Runbook | Glossary
author: CSNP Architecture Team
status: Draft | Approved | Deprecated
version: 1.0
last-updated: YYYY-MM-DD
classification: Internal – <Category>
---
```

**Doc-types hiện có:** `Architecture Overview`, `Platform Standard`, `Policy`, `Playbook`, `Runbook`, `Glossary`, `Documentation Standard`, `Roadmap`, `Documentation Guide`, `Documentation Index`

**Classification pattern:** `Internal – Architecture / Platform / Security`, `Internal – CI/CD / DevSecOps`, `Internal – Governance / Source Control`, v.v.

**Cấu trúc section:** Numbered sections (1, 2, 3...), mỗi sub-section có prefix số (1.1, 1.2, 4.1 ...). Không bỏ qua số.

---

## CSNP Ecosystem — Repositories

| Repository | Loại | Mục đích |
| --- | --- | --- |
| `csnp-fintech` | Application | Wallet, Payment, Ledger, Trading, Payout, Compliance |
| `csnp-platform` | Application | Credential (SSO), Notification, Admin Portal (Blazor) |
| `csnp-social` | Application | Post, Comment, Feed, Follow *(planned)* |
| `csnp-web` | Presentation | User Web Portal (Next.js) |
| `csnp-admin` | Presentation | Admin Portal (Angular) |
| `csnp-mobile` | Presentation | Mobile App |
| `csnp-gitops-root` | GitOps | ArgoCD control plane / App-of-Apps |
| `csnp-gitops-fintech` | GitOps | Fintech application manifests |
| `csnp-gitops-platform` | GitOps | Platform service manifests |
| `csnp-gitops-social` | GitOps | Social service manifests |
| `csnp-gitops-web` | GitOps | Web UI manifests |
| `csnp-gitops-admin` | GitOps | Admin UI manifests |
| `csnp-infra` | Infrastructure | Infrastructure as Code |
| `csnp-cicd` | Infrastructure | CI/CD shared libraries & templates |
| `csnp-idp` | Infrastructure | Internal Developer Platform |
| `csnp-monitoring` | Infrastructure | Observability configuration |
| `csnp-devtools` | Developer Tooling | Internal tools (AI Team Bot, CLI, scripts) |
| **`csnp-docs`** | Documentation | Architecture, policies, SOPs, runbooks *(this repo)* |
| `csnp-public-architecture` | Documentation | Public/sanitized platform docs |

**Rules cứng:**
- Application repos: **chỉ source code + CI logic**, không có deployment manifests
- GitOps repos: **chỉ desired state**, không có source code
- Mỗi repo một concern duy nhất

---

## Architecture Overview

### Platform Layers (6 layers)

```
1. Human & External Access Layer
   → Developers, Platform Engineers, SRE, Security/Auditors
   → SSH (role-based), Web UIs (Backstage, Jenkins, ArgoCD, Harbor, Keycloak)

2. Identity & Access Management Layer (Keycloak)
   → SSO, OIDC/JWT, Role management, token issuance
   → Consumed by: Jenkins, ArgoCD, Backstage, Harbor, internal apps

3. Developer Experience & Control Plane Layer (Backstage + Git)
   → Service catalog, CI/CD visibility, documentation discovery

4. CI (Build & Verification) Layer (Jenkins Controller + Agents)
   → Build, test, package, image push → Harbor
   → NEVER deploys directly to Kubernetes

5. GitOps & Deployment Control Layer (ArgoCD)
   → Pull-based declarative deployment
   → Monitors GitOps repos → reconciles to Kubernetes clusters

6. Runtime & Platform Services Layer (Kubernetes + Edge Proxy + Harbor)
   → DEV / UAT / PRO workload environments
   → No human access to workloads; all changes via GitOps
```

### End-to-End CI/CD Flow

```
Developer pushes code
    → Git (Application Repo)
        → Jenkins triggered
            → Build / Test / Package / Image push → Harbor
                → GitOps repo updated (new image tag)
                    → ArgoCD detects change
                        → Reconciles to Kubernetes cluster
                            → Observability captures all actions
```

**Key principle:** Jenkins builds; ArgoCD deploys. Không bao giờ ngược lại.

### Network Zones (4 zones — Proxmox + pfSense)

| Zone | Bridge | Trust Level | Mục đích |
| --- | --- | --- | --- |
| WAN | `vmbr0` | Untrusted | Internet uplink |
| DMZ | `vmbr2` | Semi-trusted | Edge proxy, TLS termination |
| MGMT | `vmbr3` | Trusted | Platform services, admin (Keycloak, Jenkins, Harbor, ArgoCD, Vault) |
| LAN | `vmbr1` | Restricted | Application runtime, data |

Tất cả inter-zone routing phải qua pfSense.

### Domain Naming Standard

```
# Public UI
web.csnp.xyz (PRO), web-dev.csnp.xyz (DEV), web-uat.csnp.xyz (UAT)

# Public API
api.csnp.xyz, api-dev.csnp.xyz, api-uat.csnp.xyz

# Internal API (không public)
int-api.csnp.xyz, int-api-dev.csnp.xyz

# Admin UI / Admin API
admin.csnp.xyz, admin-api.csnp.xyz

# Platform services (internal only)
idp-dev.csnp.xyz        # Keycloak
harbor.csnp.xyz         # Container Registry
jenkins-master.csnp.xyz
argocd-dev.csnp.xyz
```

**Rules:** Microservices KHÔNG có domain riêng. Môi trường PHẢI encode trong subdomain (không encode trong path). Root `csnp.xyz` chỉ dùng cho production public UI.

---

## Key Standards & Policies

### Branching Strategy

| Branch | Environment | Đặc điểm |
| --- | --- | --- |
| `dev` | Development | Auto-trigger CI, high velocity |
| `uat` | UAT | Controlled promotion |
| `stg` | Staging | Pre-production validation |
| `pro` | Production | Gated, manual approval required |

Working branches: `feature/`, `bugfix/`, `hotfix/`, `refactor/` — short-lived, không deploy thẳng lên production.

**Rules:**
- Direct commits lên environment branches bị cấm
- Production changes phải đi từ lower environments
- Mọi change phải traceable qua Git history + PR

### Environment Promotion Policy

- Artifacts được build **một lần**, promote unchanged qua môi trường
- Không rebuild artifact cho UAT/PRO
- Promotion phải **explicit** (manual approval) qua GitOps PR
- Không bao giờ auto-promote qua environment boundaries
- Git-based audit trail bắt buộc

### Backend Engineering Rules

**Idempotency (MANDATORY):**
- Tất cả operations có thể retry phải idempotent
- Dùng DB-level guarantees (`ON CONFLICT DO NOTHING`)
- Dùng deterministic idempotency keys
- Cấm "check-then-insert" pattern

**Transaction Management:**
- Critical operations trong single DB transaction (insert record + update state + insert outbox)

**Event Naming Convention:**
- Format: `<Entity><Action>IntegrationEvent`
- Past tense bắt buộc: `WalletWithdrawnIntegrationEvent`, `PayoutSucceededIntegrationEvent`

### Money Safety Standard (Fintech)

**Non-negotiable invariants:**
- Total money in = total money out + current balance
- Financial action MUST NOT execute more than once
- All funds MUST eventually reach terminal state
- Final state MUST be consistent regardless of retries/crashes

### Documentation Standard

**Khi tạo doc mới:**
1. Luôn dùng template từ `templates/`
2. Thêm đầy đủ YAML front-matter
3. Numbered sections
4. Ghi rõ `status: Draft` cho đến khi reviewed

---

## Platform Lifecycle (Day-0 / Day-1 / Day-2)

### Day-0 — Infrastructure Bootstrap

Pre-requisite trước khi cài bất cứ platform service nào:

1. Bare-metal → Proxmox VE installation + hardening
2. Network bridges (`vmbr0`–`vmbr3`) + pfSense VM (routing/firewall)
3. Golden OS templates (Ubuntu 24.04, Rocky 10, Debian 13 XFCE)
4. Human SSH access governed + inventoried
5. Secrets bootstrap policy in effect

### Day-1 — Platform Bootstrap Order (normative)

Phải theo đúng thứ tự:

1. **Admin Bastion / Control Node** — single human entry point, dùng để chạy Terraform/Ansible
2. **Edge Proxy (Nginx)** — TLS termination, DMZ zone
3. **Keycloak (IdP)** — identity foundation, PHẢI trước mọi service khác
4. **Vault (Secrets Management)** — secrets injection cho Kubernetes
5. **Harbor (Container Registry)** — artifact storage
6. **Jenkins Controller** — CI orchestration
7. **Jenkins Agents** — build execution
8. **ArgoCD** — GitOps CD, sau khi registry & agents ready

### Day-2 — Operations

- Incident response model
- Security maintenance lifecycle  
- Backup and disaster recovery
- Upgrade and patch governance
- Runbook navigation

**Canonical playbook:** `lifecycle/operations/CSNP-Day2-Platform-Operations-Playbook.md`

---

## Security Architecture

### Identity Model (3 categories)

| Identity Type | Flow | Ví dụ |
| --- | --- | --- |
| Human Identity | OIDC Authorization Code Flow | End users, traders, backoffice staff |
| Platform Identity | OIDC SSO | Jenkins, ArgoCD, Harbor, Backstage |
| Service Identity | Client Credentials *(reserved)* | Internal services (future) |

**JWT Validation (mandatory for all services):**
- Validate issuer, audience, lifetime
- Disable default claim remapping
- `RoleClaimType = "roles"`
- KHÔNG reimplementation per-service

### Secrets Management

**HashiCorp Vault** — centralized secrets store:
- Kubernetes pods nhận secrets qua Vault Agent injection (file mount tại `/vault/secrets`)
- No-op fallback for local dev (nếu mount không tồn tại)
- Không lưu secrets trong Git, không hardcode trong pipeline

### Zero Trust Model

- Không có implicit trust giữa zones
- Tất cả access phải authenticated + authorized qua Keycloak
- Short-lived credentials preferred
- Least-privilege enforcement

---

## Service Architecture Documents (`architecture/services/`)

Mỗi service có doc riêng mô tả architectural context và design decisions:

| Service | Document |
| --- | --- |
| Wallet | `architecture/services/wallet/CSNP-Wallet-Service-Architecture.md` |
| Payment | `architecture/services/payment/CSNP-Payment-Service-Architecture.md` |
| Payout | `architecture/services/payout/CSNP-Payout-Service-Architecture.md` |
| Ledger | `architecture/services/ledger/CSNP-Ledger-Service-Architecture.md` |
| Trading | `architecture/services/trading/CSNP-Trading-Service-Architecture.md` |

**Reconciliation Architecture:** `architecture/operations/CSNP-Reconciliation-Architecture.md`
- Wallet vs Ledger reconciliation
- Payout vs Provider reconciliation
- Payment vs Provider reconciliation
- Mismatch detection và handling

---

## Governance Model

**Governance tiers:**
- **Tier-0 (Platform-Wide):** Architecture Governance Board — owns cross-domain standards
- **Architecture Team:** System design, platform architecture, canonical documents
- **DevOps / Infrastructure Team:** Infrastructure deployment, networking, runbooks
- **Security Team:** IAM, Zero Trust, audit controls, compliance mappings
- **Developers:** Follow developer guides, branching strategy, contribution rules

**Compliance alignment:**
- ISO/IEC 27001 (A.5, A.8, A.12, A.14, A.16)
- PCI-DSS v4.0 (Requirements 2, 6, 7, 10)

**Exception handling:** Mọi deviation từ standards phải documented, reviewed, approved qua Change Control (`governance/CSNP-Change-Control.md`).

---

## Operations Reference

### Platform Services Installation Guides

| Service | Guide |
| --- | --- |
| Jenkins Controller | `operations/infrastructure/platform-services/jenkins/CSNP-Jenkins-Installation-DEV.md` |
| Jenkins Agent | `operations/infrastructure/platform-services/jenkins/CSNP-Jenkins-Agent-Installation-DEV.md` |
| Harbor (Docker Compose) | `operations/infrastructure/platform-services/harbor/CSNP-Harbor-Installation-DockerCompose-DEV.md` |
| Keycloak (Podman) | `operations/infrastructure/platform-services/keycloak/CSNP-Keycloak-Installation-Podman-DEV.md` |
| Vault | `operations/infrastructure/platform-services/vault/CSNP-Vault-Installation-DEV.md` |
| ArgoCD SSH Setup | `operations/infrastructure/platform-services/argocd/CSNP-ArgoCD-GitOps-SSH-Setup.md` |
| Edge Proxy Nginx | `operations/infrastructure/platform-services/edge-proxy/CSNP-Edge-Proxy-Nginx-Installation-DEV.md` |
| Admin Bastion | `operations/infrastructure/platform-services/admin/CSNP-Admin-Bastion-VM-Standard.md` |
| Control Node | `operations/infrastructure/platform-services/admin/CSNP-Control-Node-Bootstrap-DEV.md` |

### Runbooks (`operations/runbooks/`)

| Runbook | Tình huống |
| --- | --- |
| `Break-Glass-Access.md` | Emergency access when normal auth fails |
| `Failure-Recovery-Playbook.md` | Service/infra failure recovery |
| `Revoke-Compromised-SSH-Key.md` | SSH key compromise response |
| `Rotate-Deploy-Key.md` | Deploy key rotation |
| `Rotate-Human-SSH-Key.md` | Human SSH key rotation |
| `CSNP-Jenkins-CI-Agent-Disk-Full-Runbook.md` | Jenkins agent disk full |
| `CSNP-Kubernetes-Worker-Disk-Full-Runbook.md` | K8s worker node disk full |
| `CSNP-Vault-Kubernetes-Troubleshooting-Runbook.md` | Vault K8s injection issues |

---

## Quick Navigation by Role

| Role | Bắt đầu từ |
| --- | --- |
| Mới vào team | `START-HERE.md` → `knowledge/glossary/CSNP-Glossary.md` → `learning/overview/CSNP-Enterprise-Overview.md` |
| Developer | `architecture/foundation/CSNP-CICD-Architecture.md` → `architecture/foundation/CSNP-GitOps-Architecture.md` |
| Infrastructure Engineer | `lifecycle/infrastructure/CSNP-Day0-Infrastructure-Bootstrap-Playbook.md` → Day-1 → Day-2 |
| Platform Architect | `architecture/CSNP-Platform-Big-Picture.md` → `architecture/foundation/` → `architecture/decisions/` |
| Security/Compliance | `architecture/security/` → `governance/compliance/` → `operations/network/CSNP-Network-Segmentation-Design.md` |
| Operator (SRE) | `lifecycle/operations/CSNP-Day2-Platform-Operations-Playbook.md` → `operations/runbooks/` |

---

## Key Design Principles (Cross-cutting)

- **GitOps as the only deployment mechanism** — Git is single source of truth; pull-based; no manual deploys
- **Immutable artifacts** — build once, promote unchanged (DEV → UAT → PRO)
- **Zero Trust** — no implicit trust between zones or services
- **Least privilege by default** — all access scoped and auditable
- **Auditability by design** — every change traceable via Git history
- **Day-0 → Day-1 → Day-2 sequencing is mandatory** — no shortcuts
- **Separation of concerns** — CI builds, CD deploys, never mixed
- **Microservices do NOT own public domains** — all routed via API Gateway / Ingress

---

## How to Contribute Documentation

1. Đọc `CONTRIBUTING.md` và `standards/documentation/CSNP-Documentation-Standard.md`
2. Chọn template phù hợp từ `templates/`
3. Thêm YAML front-matter đầy đủ, set `status: Draft`
4. Numbered sections bắt buộc
5. Cập nhật README.md của thư mục chứa doc mới
6. Submit PR — tất cả docs thay đổi trong production-impacting areas yêu cầu review
