# Toan Nguyen — Senior Backend & Platform Engineer

Backend and platform engineer with 16+ years of experience across fintech, enterprise, and analytics domains. I design distributed systems end-to-end — from domain-driven backend services to Kubernetes infrastructure, GitOps delivery, and cloud deployment.

---

## CSNP — Core Security Network Platform

A self-directed initiative to design and build a production-grade distributed fintech platform simulating real-world constraints at system scale — modeled after real exchange architecture. No team support. Full lifecycle ownership.

**What's inside:**

- **6 fintech bounded contexts** (.NET 10, DDD, CQRS): Wallet, Payment, Trading, Ledger, Payout, Compliance
- **Event-driven reliability**: Outbox/Inbox with MassTransit + RabbitMQ; Saga pattern for distributed transaction coordination
- **Reconciliation**: Wallet↔Ledger and Payment↔Provider boundaries — idempotency, exactly-once semantics, automated mismatch recovery
- **Trading engine**: In-memory order matching with `Channel<T>`, price-time priority order book, real-time SignalR feed
- **Infrastructure from bare-metal**: Proxmox VE → VM provisioning (Terraform + Ansible) → Kubernetes (kubeadm v1.35, Calico CNI)
- **Network segmentation**: pfSense 4-zone architecture (WAN / LAN / DMZ / MGMT), Zero Trust isolation
- **AWS deployment**: VPC multi-AZ, EKS + IRSA (OIDC), ALB Ingress — full Internet → ALB → Pod flow verified
- **GitOps delivery**: ArgoCD App-of-Apps, Jenkins shared-library CI, Harbor registry, DEV → UAT → PROD promotion
- **Security**: Keycloak OIDC/RBAC, HashiCorp Vault secrets injection, PCI-DSS v4.0 and ISO/IEC 27001 aligned
- **Load tested (k6)**: 80 VUs, 5 min — 31,191 iterations, ~103 req/s, p(95)=649ms, 99.99% success rate
- **Documentation**: 185+ docs — ADRs, C4/UML, HLD/LLD, runbooks, Day-0 → Day-2 operational playbooks

---

## Tech Stack

| Layer | Stack |
|---|---|
| Backend | .NET 10 / C#, Go |
| Architecture | Clean Architecture, DDD, CQRS, Outbox/Inbox, Saga, Reconciliation |
| Messaging | MassTransit, RabbitMQ, Kafka, SignalR |
| Data | PostgreSQL, Redis, MongoDB, SQL Server |
| Platform | Kubernetes (kubeadm + EKS), Helm, ArgoCD, Jenkins, Harbor |
| Cloud & IaC | AWS (VPC, EKS, ALB, IRSA, S3), Terraform, Ansible, Proxmox VE |
| Networking | pfSense, Zero Trust, 4-zone segmentation |
| Security | Keycloak, HashiCorp Vault, SSH governance |
| Observability | Prometheus, Grafana, Loki, k6 |

---

> Building distributed systems that are reliable, auditable, and operationally correct — from domain model to production.
