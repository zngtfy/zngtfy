Senior backend and platform engineer with 18+ years of experience across fintech, enterprise, and analytics domains.

I work across backend, platform, and product delivery — from domain-driven services and identity boundaries to Kubernetes, GitOps, cloud deployment, and BFF-backed web/admin apps.

──────────────────────────────────────

CSNP — Core Services Network Platform

A personal, self-funded engineering project I designed and built end-to-end to simulate real-world constraints at system scale — modeled after exchange-style fintech architecture.

What I built:
• 6 fintech bounded contexts (.NET 10/C#, DDD, CQRS): Wallet, Payment, Trading, Ledger, Payout, Compliance
• Reconciliation across Wallet↔Ledger and Payment↔Provider boundaries with idempotency and exactly-once semantics
• Event-driven reliability: Outbox/Inbox (MassTransit + RabbitMQ), Saga pattern for distributed transaction coordination
• Java/Spring Boot Identity Service with OIDC/JWT validation, authorization decision APIs, Keycloak and AWS Cognito verified across DEV/UAT/PROD, and Auth0-ready boundaries
• Go BFF, Angular admin, and Next.js web applications using same-origin access patterns
• Infrastructure from bare metal up: Proxmox → Terraform + Ansible → Kubernetes → ArgoCD GitOps
• AWS deployment: VPC multi-AZ, EKS with IRSA, ALB Ingress — full Internet→Pod flow verified
• Security: OIDC/JWT, HashiCorp Vault, pfSense 4-zone network segmentation, PCI-DSS v4.0 aligned design
• Load tested at 80 VUs for 5 minutes: 31,191 iterations, ~103 req/s, p(95)=649ms, 99.99% success rate
• 185+ architecture docs: ADRs, C4/UML, HLD/LLD, runbooks, Day-0→Day-2 playbooks

──────────────────────────────────────

Core strengths:
• Backend architecture: Clean Architecture, DDD, CQRS, Outbox/Inbox, Saga, Reconciliation
• Platform: Kubernetes (kubeadm + EKS), ArgoCD, Jenkins CI, Harbor, Helm
• Cloud & IaC: AWS (VPC/EKS/ALB/IRSA), Terraform, Ansible, Proxmox
• Security: Keycloak, AWS Cognito, Auth0-ready OIDC boundary, HashiCorp Vault, Zero Trust
• Languages & data: .NET 10/C#, Go, Java/Spring Boot, PostgreSQL, Redis, MongoDB, RabbitMQ, Kafka
• Presentation: Angular, Next.js, React, TypeScript, same-origin BFF

Open to senior backend, platform, or hybrid/full-stack product delivery roles in reliable distributed systems, especially fintech or high-scale products.
