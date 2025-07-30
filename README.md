# 🚀 Open-Sourcing CSNP — Comic Social Network Platform

Hi, I'm **Toan Nguyen (aka zngtfy)** – a backend developer passionate about system architecture, clean code, and distributed systems.  
This project is my exploration into how modern microservices can scale across social and fintech domains.

---

## 💡 What is CSNP?

**CSNP (Comic Social Network Platform)** is a polyglot microservices backend built for modern social and fintech use cases.  
The platform applies clean architecture principles, distributed messaging, and Kubernetes-native deployment.

Key architecture highlights:

- 🧱 **Domain-Driven Design (DDD)**
- ⚙️ **CQRS** with MediatR (in .NET)
- 📨 **Event-Driven Architecture** using RabbitMQ + MassTransit
- 🔁 **Saga Pattern** for distributed transactions
- 🔐 **Centralized SSO** with OpenIddict
- ☸️ **Kubernetes-native deployments** (ArgoCD, Helm, Harbor)
- 💾 Storage: PostgreSQL, Redis, MinIO
- 🧠 Polyglot services: `.NET`, `Spring Boot`, `NestJS`

---

## 📦 Core Services Overview

### 🔐 Web API (.NET 9) — SSO + Notification + Social Video

Acts as the central hub for authentication and system-wide services.

- OpenIddict-based SSO
- Email notification (background service)
- Social features: post short videos, comment (TikTok-style)
- Shared Kernel: `ValueObject`, `DomainEvent`, `Entity<T>`
- PostgreSQL, Redis, MinIO
- Helm chart for Kubernetes

🔗 [Code](https://github.com/skg-csnp/api-web)

---

### 💸 Fintech API (.NET 9) — Wallet + Event-Driven + Saga

Models wallet operations like top-up, transfer, and history.

- CQRS with MediatR
- Event publishing via RabbitMQ + MassTransit
- Saga orchestration
- PostgreSQL, Helm/Kubernetes

🔗 [Code](https://github.com/skg-csnp/api-fintech)

---

### 📱 Mobile Gateway (Spring Boot)

Backend gateway for mobile app access to platform services.

- RESTful gateway controller
- Redis cache
- Liquibase for DB migration
- Kubernetes-ready config

🔗 [Code](https://github.com/skg-csnp/api-mobile)

---

### 🛠 Admin Portal API (NestJS)

Admin backend to manage system and user settings.

- CQRS modular pattern
- Prisma ORM
- Role-Based Access Control (RBAC)
- Shared SSO Authentication
- Kubernetes deployment ready

🔗 [Code](https://github.com/skg-csnp/api-admin)

---

## 🔗 About Me

I'm currently deep-diving into:
- DDD, CQRS, and Event-Driven Design
- Kubernetes and DevOps tooling
- Building scalable, maintainable backend systems

📫 Connect with me:
- GitHub: [zngtfy](https://github.com/zngtfy)
- LinkedIn: [Toan Nguyen](https://www.linkedin.com/in/toan-nguyen-van-0b8b73123/)
- Email: nvt87x@gmail.com

---

Thanks for stopping by! If you're into architecture, DevOps, or building awesome backend systems — feel free to connect 🙌
