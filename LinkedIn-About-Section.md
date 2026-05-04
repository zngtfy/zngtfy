Senior backend and platform engineer with 16+ years of experience building distributed systems across fintech, enterprise, and analytics domains.

I work across the full stack — from domain-driven backend services and event-driven architecture to Kubernetes platform infrastructure, GitOps delivery, and cloud deployment. My focus is on reliability, operational correctness, and end-to-end system ownership.

──────────────────────────────────────

CSNP — Core Security Network Platform

A self-directed platform engineering initiative I designed and built end-to-end to simulate real-world production constraints at system scale — modeled after real exchange architecture.

What I built:
• 6 fintech bounded contexts (.NET 10, DDD, CQRS): Wallet, Payment, Trading, Ledger, Payout, Compliance
• Reconciliation architecture across Wallet↔Ledger and Payment↔Provider boundaries with idempotency and exactly-once semantics
• Event-driven reliability: Outbox/Inbox (MassTransit + RabbitMQ), Saga pattern for distributed transaction coordination
• Infrastructure from bare-metal up: Proxmox → Terraform + Ansible → Kubernetes (kubeadm v1.35) → ArgoCD GitOps
• AWS deployment: VPC multi-AZ, EKS with IRSA, ALB Ingress — full Internet→Pod flow verified
• Zero Trust security: Keycloak OIDC/RBAC, HashiCorp Vault, pfSense 4-zone network segmentation, PCI-DSS v4.0 aligned
• Load tested at 80 VUs for 5 minutes: 31,191 iterations, ~103 req/s, p(95)=649ms, 99.99% success rate
• 185+ architectural documents: ADRs, C4/UML diagrams, HLD/LLD specs, runbooks, Day-0→Day-2 playbooks

──────────────────────────────────────

Core strengths:
• Backend architecture: Clean Architecture, DDD, CQRS, Outbox/Inbox, Saga, Reconciliation
• Platform: Kubernetes (kubeadm + EKS), ArgoCD, Jenkins CI, Harbor, Helm
• Cloud & IaC: AWS (VPC/EKS/ALB/IRSA), Terraform, Ansible, Proxmox
• Security: Keycloak, HashiCorp Vault, Zero Trust, PCI-DSS
• Languages & data: .NET 10/C#, Go, PostgreSQL, Redis, RabbitMQ, Kafka

Open to senior backend, platform, or hybrid roles — especially in distributed systems, fintech infrastructure, or cloud-native environments. Remote or international welcome.
