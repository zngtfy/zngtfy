# CSNP Docs - Codebase Guide for Claude

## Project Overview

`csnp-docs` is the central documentation hub for the CSNP ecosystem
(Core Services Network Platform). This is a documentation-only repository. It
does not contain application source code and does not build deployable
artifacts. Documents are Markdown files with standard YAML front matter.

Repository goals:

- Centralize architecture, operations, governance, security, and onboarding
  knowledge.
- Serve Developers, Infrastructure Engineers, Platform Architects,
  Security/Compliance, and Operators/SREs.
- Keep platform decisions and operational guidance auditable and easy to find.

Entry points:

- `README.md` - Documentation hub index.
- `START-HERE.md` - Role-based reading guide for new readers.
- `knowledge/strategy/CSNP-Full-Execution-Roadmap.md` - End-to-end execution roadmap.

Important routing rule:

- BFF has no dedicated public hostname. Web uses same-origin `/bff/*`; Admin
  uses same-origin `/api/*`.

---

## Repository Structure

```text
csnp-docs/
|-- README.md                    # Central navigation hub
|-- START-HERE.md                # Role-based entry point
|-- CONTRIBUTING.md              # Documentation contribution rules
|-- architecture/                # System and platform architecture
|   |-- CSNP-Platform-Big-Picture.md
|   |-- foundation/              # Foundation architecture
|   |-- cicd/                    # CI/CD architecture and Jenkins standards
|   |-- decisions/               # Architecture Decision Records
|   |-- operations/              # Reconciliation architecture
|   |-- platform/                # Control plane, security, runtime, observability
|   |-- security/                # SSH trust domain and access path overview
|   `-- services/                # Service-level architecture docs
|-- governance/                  # Governance and policy documents
|-- standards/                   # Engineering and platform standards
|-- lifecycle/                   # Day-0, Day-1, and Day-2 playbooks
|-- operations/                  # Infrastructure and operations guides
|-- guides/                      # Role-based guides
|-- knowledge/                   # Glossary, strategy, canonical knowledge
|-- learning/                    # Overview, FAQ, quickstart, troubleshooting
|-- templates/                   # Reusable documentation templates
`-- assets/                      # Diagrams and visual assets
```

---

## Document Format Standard

All documents must include YAML front matter:

```yaml
---
title: <Document Title>
doc-type: Architecture Overview | Platform Standard | Policy | Playbook | Runbook | Glossary
author: CSNP Architecture Team
status: Draft | Approved | Deprecated
version: 1.0
last-updated: YYYY-MM-DD
classification: Internal - <Category>
---
```

Current document types include:

- `Architecture Overview`
- `Platform Standard`
- `Policy`
- `Playbook`
- `Runbook`
- `Glossary`
- `Documentation Standard`
- `Roadmap`
- `Documentation Guide`
- `Documentation Index`

Section structure:

- Use numbered sections.
- Use numbered subsections such as `1.1`, `1.2`, and `4.1`.
- Do not skip section numbers.
- Write documentation in English.

---

## CSNP Ecosystem Repositories

| Repository | Type | Purpose |
| --- | --- | --- |
| `csnp-identity` | Application | Enterprise IAM, identity mapping, RBAC/ABAC authorization, permission evaluation |
| `csnp-fintech` | Application | Wallet, Payment, Ledger, Settlement |
| `csnp-compliance` | Application | KYC, AML detection, suspicious activity reporting |
| `csnp-platform` | Application | Audit, Notification, Workflow, Document, shared platform services |
| `csnp-tradefinance` | Application | Schedule of Offer, Invoice Financing, Factoring, LC/TR, Fund Request, Customer Limit |
| `csnp-social` | Application | Post, Comment, Feed, Follow |
| `csnp-web` | Presentation | User Web Portal built with Next.js |
| `csnp-admin` | Presentation | Admin Portal built with Angular |
| `csnp-mobile` | Presentation | Mobile App |
| `csnp-bff` | BFF | Go BFF services for Web/Admin: `bff-web` and `bff-admin` |
| `csnp-gitops-root` | GitOps | ArgoCD control plane / App-of-Apps |
| `csnp-gitops-fintech` | GitOps | Fintech application manifests |
| `csnp-gitops-compliance` | GitOps | Compliance service manifests |
| `csnp-gitops-platform` | GitOps | Platform service manifests |
| `csnp-gitops-identity` | GitOps | Identity service manifests |
| `csnp-gitops-tradefinance` | GitOps | Trade Finance service manifests |
| `csnp-gitops-social` | GitOps | Social service manifests |
| `csnp-gitops-web` | GitOps | Web UI manifests |
| `csnp-gitops-admin` | GitOps | Admin UI manifests |
| `csnp-gitops-bff` | GitOps | BFF workload manifests; same-origin routing follows ADR-0004 |
| `csnp-infra` | Infrastructure | Infrastructure as Code |
| `csnp-cicd` | Infrastructure | CI/CD shared libraries and templates |
| `csnp-idp` | Infrastructure | Internal Developer Platform |
| `csnp-monitoring` | Infrastructure | Observability configuration |
| `csnp-devtools` | Developer Tooling | Internal tools, CLI, and scripts |
| `csnp-docs` | Documentation | Architecture, policies, SOPs, runbooks |
| `csnp-public-architecture` | Documentation | Public/sanitized platform docs |

Rules:

- Application repositories contain source code and CI logic only.
- GitOps repositories contain desired state only.
- Each repository has one clear concern.

---

## Architecture Overview

### Platform Layers

```text
1. Human and External Access Layer
   -> Developers, Platform Engineers, SRE, Security/Auditors
   -> SSH, Backstage, Jenkins, ArgoCD, Harbor, Keycloak

2. Identity and Access Management Layer
   -> Platform SSO via Keycloak
   -> Application identity via csnp-identity
   -> csnp-identity supports Keycloak, Cognito, and Entra ID per deployment
   -> Consumed by Jenkins, ArgoCD, Backstage, Harbor, BFF, internal apps

3. Developer Experience and Control Plane Layer
   -> Backstage, Git, service catalog, CI/CD visibility

4. CI Layer
   -> Jenkins builds, tests, packages, and pushes images to Harbor
   -> Jenkins never deploys directly to Kubernetes

5. GitOps and Deployment Control Layer
   -> ArgoCD reconciles Kubernetes clusters from GitOps repositories

6. Runtime and Platform Services Layer
   -> DEV, UAT, and PRO workload environments
   -> No human access to workloads; all changes go through GitOps
```

Key principle: Jenkins builds; ArgoCD deploys.

### Network Zones

| Zone | Bridge | Trust Level | Purpose |
| --- | --- | --- | --- |
| WAN | `vmbr0` | Untrusted | Internet uplink |
| DMZ | `vmbr2` | Semi-trusted | Edge proxy, TLS termination |
| MGMT | `vmbr3` | Trusted | Platform services and admin tools |
| LAN | `vmbr1` | Restricted | Application runtime and data |

All inter-zone routing must go through pfSense.

### Domain Naming Standard

```text
# Public UI
csnp.xyz (PRO), dev.csnp.xyz (DEV), uat.csnp.xyz (UAT)

# Public API
api.csnp.xyz, api-dev.csnp.xyz, api-uat.csnp.xyz

# Internal API
int-api.csnp.xyz, int-api-dev.csnp.xyz

# Admin UI
admin.csnp.xyz, admin-dev.csnp.xyz, admin-uat.csnp.xyz

# Same-origin BFF routing
dev.csnp.xyz/bff/*             -> csnp-dev-bff-web
uat.csnp.xyz/bff/*             -> csnp-uat-bff-web
csnp.xyz/bff/*                 -> csnp-pro-bff-web
admin-dev.csnp.xyz/api/*       -> csnp-dev-bff-admin
admin-uat.csnp.xyz/api/*       -> csnp-uat-bff-admin
admin.csnp.xyz/api/*           -> csnp-pro-bff-admin

# Platform services
idp-dev.csnp.xyz        # Keycloak
harbor.csnp.xyz         # Container Registry
jenkins-master.csnp.xyz
argocd-dev.csnp.xyz
```

Rules:

- Microservices do not own public domains.
- Environment must be encoded in the subdomain, not the path.
- Root `csnp.xyz` is reserved for the production public UI.
- Web/Admin browsers do not call `api-<env>.csnp.xyz` directly.

---

## Identity and Presentation Boundaries

- `csnp-platform/src/Credential` is a legacy Keycloak-only identity integration
  boundary.
- `csnp-identity` is the canonical application identity service.
- `csnp-identity` supports Keycloak, Cognito, and Entra ID per deployment.
- The canonical user reference is `UserId`.
- Provider subjects and claims must be mapped to `UserId` before downstream use.
- `csnp-web` and `csnp-admin` currently access backend capabilities through
  `csnp-bff`.
- Direct public API access from presentation apps is a customer-specific
  deployment variant, not the default implementation path.

---

## Key Standards and Policies

### Branching Strategy

| Branch | Environment | Characteristics |
| --- | --- | --- |
| `dev` | Development | Auto-trigger CI, high velocity |
| `uat` | UAT | Controlled promotion |
| `stg` | Staging | Pre-production validation |
| `pro` | Production | Gated, manual approval required |

Rules:

- Direct commits to environment branches are prohibited.
- Production changes must be promoted from lower environments.
- Every change must be traceable through Git history and PR review.

### Environment Promotion Policy

- Build artifacts once and promote them unchanged across environments.
- Do not rebuild artifacts for UAT or PRO.
- Promotion must be explicit through GitOps PRs.
- Never auto-promote across environment boundaries.
- Git-based audit trail is mandatory.

### Backend Engineering Rules

Idempotency:

- Retryable operations must be idempotent.
- Use database-level guarantees such as `ON CONFLICT DO NOTHING`.
- Use deterministic idempotency keys.
- Avoid check-then-insert patterns.

Transaction management:

- Critical operations must use one database transaction when state and outbox
  records must commit together.

Event naming:

- Use `<Entity><Action>IntegrationEvent`.
- Use past tense, such as `WalletWithdrawnIntegrationEvent` or
  `PayoutSucceededIntegrationEvent`.

### Money Safety Standard

- Total money in equals total money out plus current balance.
- Financial actions must not execute more than once.
- Funds must eventually reach a terminal state.
- Final state must be consistent regardless of retries or crashes.

### Documentation Standard

When creating a new document:

1. Use a template from `templates/`.
2. Add complete YAML front matter.
3. Use numbered sections.
4. Set `status: Draft` until reviewed.
5. Update the nearest relevant README/index.
6. Write in English.

---

## Platform Lifecycle

### Day-0 - Infrastructure Bootstrap

Prerequisites before installing any platform service:

1. Bare-metal to Proxmox VE installation and hardening.
2. Network bridges (`vmbr0` to `vmbr3`) and pfSense routing/firewall.
3. Golden OS templates.
4. Governed and inventoried human SSH access.
5. Secrets bootstrap policy.

### Day-1 - Platform Bootstrap Order

The normative order is:

1. Admin Bastion / Control Node.
2. Edge Proxy (Nginx).
3. Keycloak as the platform IdP for control-plane SSO.
4. Vault for secrets management.
5. Harbor as the container registry.
6. Jenkins Controller.
7. Jenkins Agents.
8. ArgoCD for GitOps CD after registry and agents are ready.

### Day-2 - Operations

- Incident response model.
- Security maintenance lifecycle.
- Backup and disaster recovery.
- Upgrade and patch governance.
- Runbook navigation.

Canonical playbook:

- `lifecycle/operations/CSNP-Day2-Platform-Operations-Playbook.md`

---

## Security Architecture

### Identity Model

| Identity Type | Flow | Example |
| --- | --- | --- |
| Human Identity | OIDC Authorization Code Flow | End users, traders, backoffice staff |
| Platform Identity | OIDC SSO | Jenkins, ArgoCD, Harbor, Backstage |
| Service Identity | Client Credentials | Internal services |

JWT validation:

- Validate issuer, audience, and lifetime.
- Disable default claim remapping.
- Use `RoleClaimType = "roles"`.
- Do not reimplement JWT validation per service.

### Secrets Management

HashiCorp Vault is the centralized secrets store:

- Kubernetes pods receive secrets through Vault Agent injection.
- Local development may use a no-op fallback when the mount is absent.
- Do not store secrets in Git.
- Do not hardcode secrets in pipelines.

### Zero Trust Model

- No implicit trust between zones.
- Platform/control-plane access must authenticate and authorize through Keycloak.
- Application user access goes through the UI/BFF and `csnp-identity` boundary.
- External identity provider subjects must map to canonical `UserId`.
- Prefer short-lived credentials.
- Enforce least privilege.

---

## Service Architecture Documents

| Service | Document |
| --- | --- |
| Wallet | `architecture/services/wallet/CSNP-Wallet-Service-Architecture.md` |
| Payment | `architecture/services/payment/CSNP-Payment-Service-Architecture.md` |
| Payout | `architecture/services/payout/CSNP-Payout-Service-Architecture.md` |
| Ledger | `architecture/services/ledger/CSNP-Ledger-Service-Architecture.md` |
| Trading | `architecture/services/trading/CSNP-Trading-Service-Architecture.md` |

Reconciliation architecture:

- `architecture/operations/CSNP-Reconciliation-Architecture.md`

---

## Governance Model

Governance tiers:

- Tier-0 Platform-Wide: Architecture Governance Board.
- Architecture Team: system design, platform architecture, canonical documents.
- DevOps / Infrastructure Team: infrastructure deployment, networking, runbooks.
- Security Team: IAM, Zero Trust, audit controls, compliance mappings.
- Developers: developer guides, branching strategy, contribution rules.

Compliance alignment:

- ISO/IEC 27001.
- PCI-DSS v4.0.

Exception handling:

- Deviations from standards must be documented, reviewed, and approved through
  `governance/CSNP-Change-Control.md`.

---

## Operations Reference

### Platform Services Installation Guides

| Service | Guide |
| --- | --- |
| Jenkins Controller | `operations/infrastructure/platform-services/jenkins/CSNP-Jenkins-Installation-DEV.md` |
| Jenkins Agent | `operations/infrastructure/platform-services/jenkins/CSNP-Jenkins-Agent-Installation-DEV.md` |
| Harbor | `operations/infrastructure/platform-services/harbor/CSNP-Harbor-Installation-DockerCompose-DEV.md` |
| Keycloak | `operations/infrastructure/platform-services/keycloak/CSNP-Keycloak-Installation-Podman-DEV.md` |
| Vault | `operations/infrastructure/platform-services/vault/CSNP-Vault-Installation-DEV.md` |
| ArgoCD SSH Setup | `operations/infrastructure/platform-services/argocd/CSNP-ArgoCD-GitOps-SSH-Setup.md` |
| Edge Proxy Nginx | `operations/infrastructure/platform-services/edge-proxy/CSNP-Edge-Proxy-Nginx-Installation-DEV.md` |
| Admin Bastion | `operations/infrastructure/platform-services/admin/CSNP-Admin-Bastion-VM-Standard.md` |
| Control Node | `operations/infrastructure/platform-services/admin/CSNP-Control-Node-Bootstrap-DEV.md` |

### Runbooks

| Runbook | Situation |
| --- | --- |
| `Break-Glass-Access.md` | Emergency access when normal auth fails |
| `Failure-Recovery-Playbook.md` | Service or infrastructure failure recovery |
| `Revoke-Compromised-SSH-Key.md` | SSH key compromise response |
| `Rotate-Deploy-Key.md` | Deploy key rotation |
| `Rotate-Human-SSH-Key.md` | Human SSH key rotation |
| `CSNP-Jenkins-CI-Agent-Disk-Full-Runbook.md` | Jenkins agent disk full |
| `CSNP-Kubernetes-Worker-Disk-Full-Runbook.md` | Kubernetes worker node disk full |
| `CSNP-Vault-Kubernetes-Troubleshooting-Runbook.md` | Vault Kubernetes injection issues |

---

## Quick Navigation by Role

| Role | Start With |
| --- | --- |
| New team member | `START-HERE.md` -> `knowledge/glossary/CSNP-Glossary.md` -> `learning/overview/CSNP-Enterprise-Overview.md` |
| Developer | `architecture/foundation/CSNP-CICD-Architecture.md` -> `architecture/foundation/CSNP-GitOps-Architecture.md` |
| Infrastructure Engineer | `lifecycle/infrastructure/CSNP-Day0-Infrastructure-Bootstrap-Playbook.md` -> Day-1 -> Day-2 |
| Platform Architect | `architecture/CSNP-Platform-Big-Picture.md` -> `architecture/foundation/` -> `architecture/decisions/` |
| Security/Compliance | `architecture/security/` -> `governance/compliance/` -> `operations/network/CSNP-Network-Segmentation-Design.md` |
| Operator/SRE | `lifecycle/operations/CSNP-Day2-Platform-Operations-Playbook.md` -> `operations/runbooks/` |

---

## Key Design Principles

- GitOps is the only deployment mechanism.
- Git is the single source of truth for desired state.
- Build immutable artifacts once and promote them unchanged.
- Use Zero Trust boundaries; do not rely on implicit network trust.
- Apply least privilege by default.
- Make every change auditable through Git history.
- Follow Day-0, Day-1, and Day-2 sequencing.
- Keep CI and CD responsibilities separate.
- Microservices do not own public domains.

---

## How to Contribute Documentation

1. Read `CONTRIBUTING.md` and `standards/documentation/CSNP-Documentation-Standard.md`.
2. Choose the appropriate template from `templates/`.
3. Add complete YAML front matter and set `status: Draft`.
4. Use numbered sections.
5. Update the README for the directory that contains the new document.
6. Submit a PR; production-impacting documentation changes require review.
