# CSNP Platform — Codebase Guide

## Quick Reference

**CSNP Platform** (Core Security Network Platform) is a production-grade, cloud-native microservices platform built on **.NET 10**, following **DDD**, **Clean Architecture**, **CQRS**, and **Event-Driven** patterns. It is the identity, notification, and mobile backend backbone for the broader CSNP ecosystem.

|                   |                                                      |
| ----------------- | ---------------------------------------------------- |
| **Runtime**       | .NET 10 / C# 13 (nullable enabled)                   |
| **Database**      | PostgreSQL 16.9 (single instance, schema-isolated)   |
| **Broker**        | RabbitMQ 4.1.2 + MassTransit 8.5.8                   |
| **Cache**         | Redis 8.0.2 (ACL-protected)                          |
| **Auth**          | Keycloak (external IdP) + local user sync middleware |
| **CQRS**          | MediatR 14.1.0 + FluentValidation 12.1.1             |
| **Storage**       | MinIO (S3-compatible, email templates)               |
| **Observability** | Serilog + OpenTelemetry + Prometheus + Grafana       |
| **Orchestration** | Kubernetes + ArgoCD (GitOps) + Vault (secrets)       |
| **Registry**      | Docker Hub (`docker.io/skgc`)                        |
| **Frontend**      | Blazor WebAssembly                                   |

**Solution files:** `CsnpPlatform.sln` (all), `CsnpCredential.sln`, `CsnpNotification.sln`, `CsnpMobilebff.sln`

**Total projects:** 37 (.csproj) — 10 shared libs, 13 service projects, 1 SPA, 2 migrations, 11 tests

---

## Architecture

**Pattern:** DDD + CQRS + Event-Driven Microservices

**Layers per bounded context (Credential & Notification):**

```
Presentation  (API Controllers / BaseV1Controller)
     ↓
Application   (MediatR Commands/Queries/Handlers, Validators, Consumers, Dispatcher)
     ↓
Domain        (Aggregates, Entities, Value Objects, Domain Events)
     ↑
Infrastructure (EF Core, Repositories, External Services)
    └── Persistence/  (separate sub-project isolating EF Core concerns)
```

> **Mobilebff** has no Domain or Infrastructure layers — it is a pure HTTP relay (Application + API only).

**Deployment:** Kubernetes, multi-environment `dev` → `uat` → `pro` via ArgoCD/Kustomize

---

## Services

| Service                | Path                                      | Purpose                                                                                                                 | Containers                     |
| ---------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| **Credential**         | `src/Credential/`                         | Auth/SSO via Keycloak; syncs first-login users; publishes `UserSyncedIntegrationEvent`                                  | 1 API                          |
| **Notification**       | `src/Notification/`                       | Sends welcome emails on user sync; templates in MinIO; logs all delivery                                                | 1 API (placeholder) + 1 Worker |
| **Presentation — Zor** | `src/Presentation/Csnp.Presentation.Zor/` | Blazor WASM admin portal served via Nginx                                                                               | 1 SPA                          |
| **Mobilebff**          | `src/Mobilebff/`                          | BFF for Android client; aggregates wallet, trading, payment, ledger, auth flows from `csnp-fintech` downstream services | 1 API                          |

> **Notification.Api** contains only a placeholder (`WeatherForecastController`). All business logic is in the Worker.

> **Notification Worker** consumes `UserSyncedIntegrationEvent` directly via MassTransit — no `InboxProcessorWorker`. Business logic runs inline in `UserSyncedConsumer`.

---

## Shared Libraries (`shared/`)

| Library                            | Purpose / Key Types                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Csnp.SeedWork`                    | Pure DDD, no EF Core: `ValueObject`, `EmailAddress`, `InvalidEmailException`, domain exceptions                                                                                                                                                                                                                                                                                                                                 |
| `Csnp.SharedKernel.Domain`         | Base entity hierarchy: `EntityBase<TId>`, `DomainEntity<TId>`, `AuditableEntity<TId>`, `ImmutableEntity<TId>`, `PersistedEntity<TId>`, `IAggregateRoot`, `IDomainEvent`, `IDomainHandler<T>`, `OutboxMessage`, `InboxMessage`, `MessageStatus`                                                                                                                                                                                  |
| `Csnp.SharedKernel.Application`    | `ValidationBehavior<,>` (only MediatR behavior registered); abstractions: `IReadRepository<>`, `IWriteRepository<>`, `IUnitOfWork<>`, `ICompositeDomainEventDispatcher`, `IDomainToIntegrationDispatcher`, `IExternalUserSynchronizer`, `IAggregateMapper`, `IMessageIdempotencyStore`, `IWebhookIdempotencyStore`; impl: `CompositeDomainEventDispatcher`; exceptions: `ConcurrencyConflictException`, `DuplicateKeyException` |
| `Csnp.SharedKernel.Infrastructure` | `ReadRepositoryBase<>`, `WriteRepositoryBase<>`, `UnitOfWork<>`, `OutboxPublisherWorker`, `OutboxMessageRepository`, `InboxMessageRepository`, `InboxDlqMessageEntity`, `RedisMessageIdempotencyStore`, `RedisWebhookIdempotencyStore`, `DomainEventHandlerDispatcher`; DI: `AddModuleApplication`, `AddPostgresDbContext`, `AddIdGenerator`, `AddMessaging<TContext>`, `AddOutbox<TContext>`                                   |
| `Csnp.SharedKernel.Configuration`  | `AddCsnpConfigurations`, `AddCsnpWorkerConfiguration`, `VaultFileConfigurationProvider`; typed settings: `PostgreSqlSettings`, `RedisSettings`, `RabbitMqSettings`, `KeycloakSettings`, `MinioSettings`, `EmailSettings`, `JwtSettings`, `CorsSettings`, `DocumentationSettings`                                                                                                                                                |
| `Csnp.SharedKernel.Observability`  | `AddCspnObservability()`, `UseCspnObservability()` — wires Serilog, OpenTelemetry, health checks (`/health`, `/health/live`, `/health/ready`)                                                                                                                                                                                                                                                                                   |
| `Csnp.Contracts`                   | Integration event DTOs shared with `csnp-fintech` — see [Integration Events](#integration-events)                                                                                                                                                                                                                                                                                                                               |
| `Csnp.EventBus`                    | MassTransit/RabbitMQ abstractions: `IIntegrationEventPublisher`, `IIntegrationHandler<T>`, `IIntegrationEventMetadata<T>`, `RabbitMqPublisher`, `MassTransitExtensions`, `MassTransitEndpointExtensions`                                                                                                                                                                                                                        |
| `Csnp.Presentation.Common`         | `BaseV1Controller` (injects `IMediator`), `ApiResponse<T>`, `ApiResponseFactory`, `ErrorHandlingMiddleware`, `ValidationFilter`, `CommonServiceExtensions`, `CommonPipelineExtensions`, `CorsExtensions`, `DocumentationExtensions`                                                                                                                                                                                             |
| `Csnp.Security.Infrastructure`     | `AddKeycloakJwtAuthentication()`, `AddExternalUserSynchronization()` middleware                                                                                                                                                                                                                                                                                                                                                 |

> **MediatR pipeline:** Only `ValidationBehavior` is registered via `AddModuleApplication()`. Do **not** add `LoggingBehavior` or `PerformanceBehavior` unless explicitly asked.

---

## Credential Service

**Domain aggregate:** `User : AuditableEntity<long>, IAggregateRoot`

| Field               | Type                                    |
| ------------------- | --------------------------------------- |
| `id`                | `long`                                  |
| `email`             | `EmailAddress`                          |
| `display_name`      | `string`                                |
| `external_id`       | `string?`                               |
| `external_provider` | `string?`                               |
| `created_at`        | `DateTime`                              |
| `last_login`        | `DateTime?`                             |
| `xmin`              | PostgreSQL optimistic concurrency token |

**Domain events:** `UserCreatedDomainEvent`, `UserSignedInDomainEvent`, `UserSyncedDomainEvent`, `UserKeycloakAttributeResyncedDomainEvent`

> `UserKeycloakAttributeResyncedDomainEvent` handles re-sync of Keycloak attributes (e.g., removed attributes). It calls `User.ResyncKeycloakAttribute()` rather than `User.MarkExternalUserSynced()` to avoid side effects on subsequent syncs.

**User sync flow:**

```
Keycloak sign-in → JWT validated (AddKeycloakJwtAuthentication)
  → AddExternalUserSynchronization middleware (first login only)
    → SyncExternalUserCommand → SyncExternalUserCommandHandler
      → User entity created → UserSyncedDomainEvent raised
        → DomainToIntegrationDispatcher
          → UserSyncedIntegrationEvent written to Outbox (atomic)
            → OutboxPublisherWorker polls every 2s → RabbitMQ
```

**Application layer:** `SyncExternalUserCommand/Handler/Validator`, `GetAllUsersQuery/Handler`, `UserDto`, `DomainToIntegrationDispatcher`, domain event handlers (`UserCreatedHandler`, `UserSignedInHandler`, `UserSyncedHandler`, `UserKeycloakAttributeResyncedHandler`), abstractions: `IKeycloakAdminClient`, `IUserReadRepository`, `IUserWriteRepository`

**Infrastructure (Persistence sub-project):** `CredentialDbContext` (schema `credential`; `users`, Outbox/Inbox tables), `UserReadRepository`, `UserWriteRepository`, `UserEntityExtensions`, `UserEntity`, `UserConfiguration`

**Infrastructure (main project):** `ExternalUserSynchronizer`, `KeycloakAdminClient`

**DI registration:** `AddApplication()`, `AddInfrastructure()`, `AddCredentialMessaging()`

---

## Notification Service

**Domain aggregate:** `EmailLog : DomainEntity<long>, IAggregateRoot`

| Field           | Type       |
| --------------- | ---------- |
| `id`            | `long`     |
| `to`            | `string`   |
| `subject`       | `string`   |
| `body`          | `string`   |
| `sent_at`       | `DateTime` |
| `is_success`    | `bool`     |
| `error_message` | `string?`  |

**Email flow:**

```
UserSyncedConsumer receives UserSyncedIntegrationEvent
  → IEmailService.SendEmailAsync("signup-welcome.html", email, event)
    → IEmailTemplateRenderer renders HTML
      → IMinioTemplateLoader fetches template from MinIO (bucket: email-templates)
    → SMTP send (MailDev in dev / real SMTP in prod)
  → CreateEmailLogCommand → persists EmailLog to notification.email_logs
```

**Application layer:** `UserSyncedConsumer`, `CreateEmailLogCommand/Handler/Validator`, abstractions: `IEmailService`, `IEmailTemplateRenderer`, `IMinioTemplateLoader`, `IEmailLogWriteRepository`

**Infrastructure (Persistence sub-project):** `NotificationDbContext` (schema `notification`, table `email_logs`), `EmailLogWriteRepository`, `EmailLogEntity`, `EmailLogConfiguration`, `EmailLogAggregateMapper`

**Infrastructure (main project):** `EmailService`, `EmailTemplateRenderer`, `MinioTemplateLoader`

**DI registration:** `AddApplication()`, `AddInfrastructure()`, `AddNotificationMessaging()`

> No domain events are raised by Notification — it is a write-only consumer relative to the event bus.

---

## Mobilebff Service

**Purpose:** Backend-for-Frontend (BFF) for the Android mobile client. Aggregates, shapes, and relays requests to downstream `csnp-fintech` services (Wallet, Payment, Trading, Ledger) and Keycloak. Has no database, domain model, or message bus.

**Application layer (Use Cases):**

| Domain  | Use Cases                                                                                         |
| ------- | ------------------------------------------------------------------------------------------------- |
| Auth    | `RefreshTokenUseCase`                                                                             |
| Wallet  | `GetWalletDashboardUseCase`, `GetTransactionHistoryUseCase`, `TransferUseCase`, `WithdrawUseCase` |
| Trading | `GetMarketSummaryUseCase`, `PlaceOrderUseCase`                                                    |
| Payment | Payment use cases                                                                                 |
| Ledger  | Ledger use cases                                                                                  |

**HTTP Clients (abstractions + base):** `IWalletHttpClient`, `IPaymentHttpClient`, `ITradingHttpClient`, `ILedgerHttpClient`, `ICredentialHttpClient`, `DownstreamHttpClientBase` (shared token-forwarding logic)

**Key DTOs:** `WalletDashboardDto`, `WalletPageDto`, `TokenResponseDto`, `OrderBookDto`, `TradeDto`, `TradingBalancePageDto`; request types: `RefreshTokenRequest`, `TransferRequest`, `WithdrawRequest`, `PlaceOrderRequest`

**Validators:** `TransferRequestValidator`, `WithdrawRequestValidator`, `PlaceOrderRequestValidator`

**API Controllers:**

| Controller          | Routes                       |
| ------------------- | ---------------------------- |
| `AuthController`    | `POST /api/v1/auth/refresh`  |
| `WalletController`  | `GET/POST /api/v1/wallet/*`  |
| `TradingController` | `GET/POST /api/v1/trading/*` |
| `PaymentController` | `GET/POST /api/v1/payment/*` |
| `LedgerController`  | `GET /api/v1/ledger/*`       |

> `BffBaseController` (not `BaseV1Controller`) is the base class for Mobilebff controllers — handles auth context and does not inject `IMediator`.

**Configuration:** `DownstreamServicesSettings` (Wallet, Payment, Trading, Ledger, Keycloak URLs)

**DI registration:** `AddMobilebffApiServices()`, `UseMobilebffApiPipeline()`, `BffExceptionHandlerExtensions`

**Idempotency:** Clients generate a UUID per mutating request; BFF forwards it to downstream services, which use Redis deduplication.

---

## Messaging & Integration Events

### Outbox Pattern (Credential → Notification)

1. Domain event raised on `User` aggregate
2. `DomainToIntegrationDispatcher` converts to `UserSyncedIntegrationEvent` and writes to Outbox (same DB transaction)
3. `OutboxPublisherWorker` (hosted in Credential.Api) polls every 2 seconds with exponential-backoff retry
4. Publishes to RabbitMQ exchange `credential.user-signedup` / queue `notification-user-signedup`
5. `UserSyncedConsumer` (Notification.Worker) consumes directly — **no Inbox persistence**

### Integration Events (`Csnp.Contracts` — shared with `csnp-fintech`) {#integration-events}

| Category | Events                                                                                                                                                                                                                                                               |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Users    | `UserSyncedIntegrationEvent`                                                                                                                                                                                                                                         |
| Payments | `PaymentCompletedIntegrationEvent`, `PaymentFailedIntegrationEvent`                                                                                                                                                                                                  |
| Wallets  | `WalletDebitedForTransferIntegrationEvent`, `WalletCreditedFromTransferIntegrationEvent`, `WalletWithdrawnIntegrationEvent`, `TransferFailedIntegrationEvent`, `TransferRefundedIntegrationEvent`, `PayoutSucceededIntegrationEvent`, `PayoutFailedIntegrationEvent` |
| Trading  | `TradeMatchedIntegrationEvent`, `TradeSettledIntegrationEvent`, `TradingAccountDepositedIntegrationEvent`                                                                                                                                                            |

> Wallet, Trading, and Payment events are defined here but the corresponding services live in `csnp-fintech`.

### Idempotency

- `RedisMessageIdempotencyStore` — consumer-side message deduplication
- `RedisWebhookIdempotencyStore` — webhook deduplication
- Both backed by ACL-protected Redis

---

## Database

- **Single PostgreSQL 16.9 instance**, schema-isolated per service
- **Schema** `credential` — `users`, `outbox_messages`, `inbox_messages`
- **Schema** `notification` — `email_logs`
- Each `DbContext` uses `.HasDefaultSchema()` + snake_case column names (`builder.UseSnakeCaseNames()`)
- Separate `__EFMigrationsHistory` table per schema to avoid conflicts
- **xmin** — PostgreSQL native row version used for optimistic concurrency on `User`
- Migration projects: `migrations/Csnp.Migrations.Credential/`, `migrations/Csnp.Migrations.Notification/`
- Design-time factory: `DbContextFactory` in each migration project

---

## Project Structure

```
csnp-platform/
├── src/
│   ├── Credential/
│   │   ├── Csnp.Credential.Api/
│   │   ├── Csnp.Credential.Application/
│   │   ├── Csnp.Credential.Domain/
│   │   └── Csnp.Credential.Infrastructure/
│   │       └── Persistence/              # Separate project isolating EF Core
│   ├── Notification/
│   │   ├── Csnp.Notification.Api/        # Placeholder only (WeatherForecastController)
│   │   ├── Csnp.Notification.Application/
│   │   ├── Csnp.Notification.Domain/
│   │   ├── Csnp.Notification.Infrastructure/
│   │   │   └── Persistence/              # Separate project isolating EF Core
│   │   └── Csnp.Notification.Worker/
│   ├── Presentation/
│   │   └── Csnp.Presentation.Zor/        # Blazor WASM admin portal (nginx.conf, Dockerfile)
│   └── Mobilebff/
│       ├── Csnp.Mobilebff.Api/           # BFF controllers, DI wiring
│       └── Csnp.Mobilebff.Application/   # Use cases, HTTP clients, DTOs, validators
├── shared/                               # 10 shared libraries
├── migrations/
│   ├── Csnp.Migrations.Credential/
│   └── Csnp.Migrations.Notification/
├── tests/                                # 11 test projects
├── _environment/                         # docker-compose, .env files, seed configs
├── docs/                                 # Architecture docs and guidelines
├── .github/workflows/                    # GitHub Actions (5 service + 1 reusable)
├── Jenkinsfile                           # Legacy Jenkins pipeline
├── CsnpPlatform.sln
├── CsnpCredential.sln
├── CsnpNotification.sln
└── CsnpMobilebff.sln
```

---

## API Conventions

- **Base path:** `/api/v1/`
- **Base controller:** `BaseV1Controller` (injects `IMediator`) for Credential and Notification; `BffBaseController` for Mobilebff
- **Response format:** `ApiResponse<T>` via `ApiResponseFactory`
- **Health endpoints:** `/health`, `/health/live`, `/health/ready`
- **Swagger:** Auto-generated, enabled in non-production environments only

---

## Naming Conventions

| Artifact           | Convention                         | Example                                                       |
| ------------------ | ---------------------------------- | ------------------------------------------------------------- |
| Projects           | `Csnp.<Context>.<Layer>`           | `Csnp.Credential.Application`                                 |
| Namespaces         | `Csnp.<Context>.<Layer>.<Feature>` | `Csnp.Credential.Application.Commands.Users.SyncExternalUser` |
| Commands           | `<Action>Command`                  | `SyncExternalUserCommand`                                     |
| Queries            | `<Action>Query`                    | `GetAllUsersQuery`                                            |
| Handlers           | `<Action>Handler`                  | `SyncExternalUserCommandHandler`                              |
| Validators         | `<Action>Validator`                | `SyncExternalUserCommandValidator`                            |
| DTOs               | `<Entity>Dto`                      | `UserDto`                                                     |
| Domain Events      | `<Entity><Action>DomainEvent`      | `UserCreatedDomainEvent`                                      |
| Integration Events | `<Entity><Action>IntegrationEvent` | `UserSyncedIntegrationEvent`                                  |
| Consumers          | `<Event>Consumer`                  | `UserSyncedConsumer`                                          |

---

## Environment & Local Development

**Env files:** `_environment/<service>.env` (`credential.env`, `notification.env`, `mobilebff.env`)

**Variable convention:** `LOC_<SERVICE>_<COMPONENT>__<PROPERTY>`

```
LOC_CREDENTIAL_RABBITMQ__HOST=docker-local
LOC_CREDENTIAL_DATABASE__HOST=localhost
LOC_CREDENTIAL_KEYCLOAK__AUTHORITY=https://idp-dev.csnp.xyz/realms/csnp-local
LOC_NOTIFICATION_MINIO__ENDPOINT=localhost:9000
```

**Import scripts:** `_environment/import-env.ps1` (PowerShell), `_environment/import-env.cmd` (CMD)

**Start local services:**

```bash
cd _environment && docker-compose up -d
```

**docker-compose services:**

| Service    | Image                       | Port(s)                    | Notes                                      |
| ---------- | --------------------------- | -------------------------- | ------------------------------------------ |
| PostgreSQL | `postgres:16.9`             | 5432                       |                                            |
| Redis      | `redis:8.0.2`               | 6379                       | ACL config in `redis/users.acl`            |
| RabbitMQ   | `rabbitmq:4.1.2-management` | 5672, 15672 (UI)           | Definitions in `rabbitmq/definitions.json` |
| MinIO      | `minio/minio`               | 9000 (API), 9001 (Console) | Email templates bucket                     |
| MailDev    | `maildev/maildev`           | 1025 (SMTP), 1080 (UI)     | Dev SMTP sink                              |
| MongoDB    | `mongo:8.0.11`              | 27017                      | For `csnp-fintech` only, not this platform |

---

## Testing

**Framework:** xUnit 2.9.3 + coverlet 8.0.1 (coverage)

| Project                                       | Scope                                           |
| --------------------------------------------- | ----------------------------------------------- |
| `Csnp.Credential.Tests.Unit`                  | Isolated application logic                      |
| `Csnp.Credential.Tests.Integration`           | Full stack with real DB                         |
| `Csnp.Credential.Tests.Architecture`          | Dependency rule enforcement (NetArchTest)       |
| `Csnp.Notification.Tests.Unit`                | Isolated application logic                      |
| `Csnp.Notification.Tests.Integration`         | Full stack with real DB                         |
| `Csnp.Notification.Tests.Architecture`        | Dependency rule enforcement (NetArchTest)       |
| `Csnp.Presentation.Common.Tests.Unit`         | Shared API layer (response, middleware, filter) |
| `Csnp.SharedKernel.Application.Tests.Unit`    | `ValidationBehavior`                            |
| `Csnp.SharedKernel.Configuration.Tests.Unit`  | Config loading and environment binding          |
| `Csnp.SharedKernel.Infrastructure.Tests.Unit` | Repository base, idempotency store logic        |
| `Csnp.SeedWork.Tests.Unit`                    | `ValueObject`, `EmailAddress`                   |

---

## CI/CD

### GitHub Actions (`.github/workflows/`)

- `ci.yml` — Reusable workflow: build → test → Docker push → GitOps SSH update
- `csnp-credential-api.yml`, `csnp-notification-api.yml`, `csnp-notification-worker.yml`, `csnp-presentation-zor.yml`, `csnp-mobilebff-api.yml` — trigger on push to `dev`/`uat`/`pro`
- **Registry:** `docker.io/skgc`; image naming: `docker.io/skgc/csnp-<service>:<env>-<run_number>`
- **GitOps SSH key:** `GITOPS_<DOMAIN>_SSH_KEY` (e.g. `GITOPS_PLATFORM_SSH_KEY`)
- **Manual approval gates** via GitHub Environments for UAT/PRO

### Jenkins (`Jenkinsfile`) — Legacy

Being replaced by GitHub Actions. Same stages: build → test → Docker push (Harbor) → GitOps update.

**Deployment:** ArgoCD pulls from GitOps repo, applies Kustomize overlays to Kubernetes.

---

## Documentation (`docs/`)

| File                         | Content                                  |
| ---------------------------- | ---------------------------------------- |
| `architecture.md`            | High-level design and solution structure |
| `domain-structure.md`        | DDD layer breakdown                      |
| `domain-layer-comparison.md` | SeedWork vs SharedKernel comparison      |
| `event-driven-design.md`     | Outbox/Inbox patterns                    |
| `cqrs-pattern.md`            | CQRS implementation                      |
| `class-design.md`            | Class and object design guidelines       |
| `shared-db-schema.md`        | Database schema strategy                 |
| `restful-api-guideline.md`   | API design standards                     |
| `dotnet-format-guide.md`     | Code formatting rules                    |
| `git-iso-process.md`         | Git branching and workflow               |
