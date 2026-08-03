# CSNP Fintech — Codebase Guide for Claude

## Project Overview

**CSNP Fintech** is a production-grade enterprise fintech platform simulating a mini centralized exchange (CEX). Built on .NET 10 with DDD, CQRS, and event-driven microservices across 5 bounded contexts.

**Scale:** 62 projects total — 27 source (5 services × 5 layers + Trading.Engine + Wallet.Consumer), 10 shared libraries, 5 migration projects, 20 test projects. 11 deployable containers (1 API + 1 Worker per service + 1 Wallet.Consumer).

**Solutions:** `CsnpFintech.sln` (master) + per-service: `CsnpWallet.sln`, `CsnpPayment.sln`, `CsnpLedger.sln`, `CsnpTrading.sln`, `CsnpPayout.sln`

---

## Recent Changes

### Resilience & Retry Logic

- **Polly v7 → Microsoft.Extensions.Http.Resilience 10.5.0:** Migrated from `AddPolicyHandler` to `AddResilienceHandler` across Payment and Trading infrastructure modules. `HttpClient.Timeout` set to Infinite, delegating all timeout control to resilience layer.
- **Circuit Breaker Fix:** FailureRatio corrected from 1.0 → 0.5 in Payment and Trading (now properly fails open after 50% failure rate, not 100%).
- **Retry with Jitter:** Exponential backoff + jitter enabled to prevent retry storms (max 3 retries across services).
- **Transient Error Handling:** New `TransientDbException` standardizes PostgreSQL transient errors (SQLSTATE 40001, 40P01). Polly ResiliencePipeline configured to retry `ConcurrencyConflictException` and `TransientDbException` in Wallet command handlers.

### Idempotency & Concurrency

- **Idempotent Outbox:** Wallet outbox messages now insert with `ON CONFLICT DO NOTHING`, preventing duplicate event publication on retry. Shadow property `idempotency_key` with partial unique index enforces idempotency at DB level.
- **Fresh Scope per Retry:** Wallet command handlers (Debit, Credit, Withdraw, Refund) now use `IServiceScopeFactory` to create a fresh scope per retry attempt, ensuring short-lived transaction boundaries and preventing idle-in-transaction lock accumulation.
- **Concurrency Resolution:** EF Core ChangeTracker cleared on rollback to prevent stale entity state across retries. `DbUpdateConcurrencyException` no longer leaks as HTTP 500 — mapped to 409 or handled gracefully per context.

### Error Handling & HTTP Mapping

- **Domain Error Abstraction:** New `IDomainError` interface provides consistent error contract across all services. `DomainException` now implements `IDomainError` with structured fields: `Code` and `Message`.
- **Enhanced ErrorHandlingMiddleware:** Maps domain errors to proper HTTP responses. Logs unhandled exceptions for debugging.
- **HTTP Status Mapping:**
    - **422 Unprocessable Entity:** `InsufficientBalanceException` (trading insufficient balance), `ValidationException` (FluentValidation failures)
    - **502 Bad Gateway:** `HttpRequestException`, `TaskCanceledException` in Payment/Trading `WalletServiceClient` (upstream Wallet service unreachable)
    - **503 Service Unavailable:** `WalletServiceException` (wraps Polly circuit breaker open, HTTP failures)

### Observability & Distributed Tracing

- **W3C Trace Propagation:** `W3C traceparent` now persisted in `OutboxMessage.Metadata`, ensuring reliable trace context propagation across Kafka publish/subscribe boundaries. Kafka consumers inherit parent trace automatically.
- **OTLP Exporter:** OpenTelemetry Protocol exporter configured, reading `OTEL_EXPORTER_OTLP_ENDPOINT` for metrics and traces. Exemplar forwarding enabled for linking metrics to traces in observability backends.
- **JSON Console Logging:** Structured JSON logging includes OTel trace context (trace_id, span_id) for better log aggregation in ELK/Loki stacks.
- **Service Naming:** All services follow convention `csnp-fintech-{wallet,payment,trading,payout,ledger}` in resource attributes.
- **Sampling Strategy:** AlwaysOn in dev (capture everything), ParentBased + TraceIdRatio(0.1) in production (10% sampled).
- **Health Checks & Metrics:** `/health` endpoint now registered in `AddCsnpObservability()` and available in all services (API + workers). `/metrics` endpoint exposed for workers (Generic Host support), enabling Prometheus scraping of non-ASP.NET workers.

### Database & Connection Management

- **Connection Pool Tuning:** PostgreSQL connection pool configured: MinPoolSize=5, MaxPoolSize=200. Connection lifetime settings documented and enforced.
- **Query Timeout:** CommandTimeout set to 10 seconds globally (prevents runaway queries).
- **Disabled EF Core Retry:** EF Core built-in retry disabled to avoid retry amplification when combined with Polly ResiliencePipeline. Polly now sole source of retry logic.
- **PostgreSQL Exception Wrapping:** Repositories (WalletWriteRepository, TransactionWriteRepository) now wrap native `PostgresException` in `TransientDbException` for uniform retry handling.

### CI/CD Hardening

- **Harbor Docker Login:** Deploy pipeline now logs into Harbor before pulling migrator image (prevents auth failures in secure registries).
- **Migrator Skip Logic:** Build pipeline skips migrator container build and DB migration entirely when migration files are unchanged (improves deploy speed for non-schema changes).
- **Latest Tag Push:** Docker images pushed with both versioned tag (e.g., `dev-123`) and `latest` tag for easy rollback reference.
- **BuildKit Cache Mounts:** Dockerfile optimized with BuildKit cache mounts for apt and nuget (speeds up layer caching, reduces network I/O).
- **Wallet Migrator Hardened:** Wallet migrator build/deploy pipeline refined with improved error handling and cleanup (docker logout, rmi, git clone --depth 1).

---

## Architecture

**Pattern:** Domain-Driven Design (DDD) + CQRS + Event-Driven Microservices

**Layers per bounded context:**

```
Presentation   (API Controllers)
    ↓
Application    (MediatR Commands/Queries/Handlers, DTOs, Validators, Consumers)
    ↓
Domain         (Aggregates, Entities, Value Objects, Domain Events, Domain Services)
    ↑
Infrastructure (EF Core Persistence, External Services, Event Dispatching, Workers)
```

**Deployment:** Kubernetes with GitOps (ArgoCD), multi-environment: `dev` → `uat` → `pro`

---

## Project Layout

```
csnp-fintech/
├── src/
│   ├── Wallet/          # 6 projects: Api, Application, Domain, Infrastructure, Worker, Consumer
│   ├── Payment/         # 5 layers: Api, Application, Domain, Infrastructure, Worker
│   ├── Trading/         # 6 projects: Api, Application, Domain, Infrastructure, Worker, Engine
│   ├── Payout/          # 5 layers
│   └── Ledger/          # 5 layers (full impl)
├── shared/              # 10 shared libraries
├── migrations/          # 5 EF Core migration projects (one per service)
├── tests/               # 20 test projects (Unit + Integration + Architecture × 5 + 5 shared)
├── _environment/        # .env files per service + import scripts
├── docs/                # Architecture decision records and design docs
├── .github/workflows/   # GitHub Actions CI/CD (13 workflows: 1 reusable + 12 service-specific)
├── Jenkinsfile          # Jenkins pipeline (legacy)
└── CsnpFintech.sln      # + per-service .sln files
```

---

## Services at a Glance

| Service        | Purpose                                                                   | Status                     | Background Workers / Jobs                                                           |
| -------------- | ------------------------------------------------------------------------- | -------------------------- | ----------------------------------------------------------------------------------- |
| **Wallet**     | Wallet management, balance tracking, deposits, withdrawals, P2P transfers | Full impl                  | `OutboxPublisherWorker`, `InboxProcessorWorker`, `StuckWithdrawalRecoveryJob`       |
| **Payment**    | Payment processing (PayPal sandbox, Stripe); webhook handling             | Full impl                  | `OutboxPublisherWorker`                                                             |
| **Trading**    | In-memory order matching engine, limit/market orders, spot trading        | Full impl (+ Engine layer) | `OutboxPublisherWorker`                                                             |
| **Payout**     | External fund withdrawal processing; stuck/unknown recovery               | Full impl                  | `OutboxPublisherWorker`, `StuckPayoutRecoveryJob`, `UnknownPayoutReconciliationJob` |
| **Ledger**     | Double-entry accounting (Account, Entry, Transaction)                     | Full impl                  | —                                                                                   |
---

## Technology Stack

| Category           | Technology / Package                              | Version                 |
| ------------------ | ------------------------------------------------- | ----------------------- |
| Runtime            | .NET / ASP.NET Core                               | 10.0                    |
| Language           | C# (nullable reference types enabled)             | 13                      |
| ORM                | Entity Framework Core + Npgsql                    | 10.0.5 / 10.0.1         |
| Database           | PostgreSQL (shared instance, per-service schemas) | —                       |
| Message Broker     | MassTransit + MassTransit.RabbitMQ                | 8.5.9                   |
| Streaming (shadow) | Confluent.Kafka                                   | 2.14.0                  |
| Cache              | StackExchange.Redis — idempotency keys            | 2.12.14                 |
| CQRS               | MediatR                                           | 14.1.0                  |
| Validation         | FluentValidation                                  | 12.1.1                  |
| Auth               | Keycloak (centralized SSO) + JWT Bearer           | —                       |
| ID Generation      | IdGen (Snowflake-like distributed IDs)            | 3.0.7                   |
| Observability      | Serilog, OpenTelemetry, Prometheus, Grafana       | OTel 1.15.x             |
| Resilience         | Microsoft.Extensions.Http.Resilience              | 10.5.0                  |
| API Docs           | Swashbuckle.AspNetCore                            | 10.1.7                  |
| Testing            | xUnit + Moq + FluentAssertions                    | 2.9.3 / 4.20.72 / 8.9.0 |

---

## Shared Libraries (`shared/`)

| Library                            | Purpose                                                                                                                                                                                                                                                                   |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Csnp.SeedWork`                    | Pure DDD abstractions (`ValueObject`, `EmailAddress`, validators, exceptions) — no external NuGet dependencies                                                                                                                                                            |
| `Csnp.SharedKernel.Domain`         | Base entity types (`EntityBase`, `DomainEntity<TId>`, `AuditableEntity<TId>`, `ImmutableEntity<TId>`, `PersistedEntity<TId>`); `OutboxMessage`/`InboxMessage` entities; `IDomainEvent`, `IDomainEventHandler<T>`                                                          |
| `Csnp.SharedKernel.Application`    | `ValidationBehavior` (the **only** MediatR pipeline behavior); `IDomainError` abstraction + `TransientDbException` for standardized error handling; idempotency, identity, persistence, mapping, event dispatching abstractions                                           |
| `Csnp.SharedKernel.Infrastructure` | Base repositories, EF Core helpers, `OutboxPublisherWorker`, `InboxProcessorWorker`, `RedisMessageIdempotencyStore`, `KafkaEventPublisher`; DI extensions: `AddModuleApplication`, `AddPostgresDbContext`, `AddIdGenerator`, `AddMessaging<TContext>`, `AddKafkaProducer` |
| `Csnp.SharedKernel.Configuration`  | `AddCsnpConfigurations()` settings binding, Vault file provider, typed settings classes (PostgreSQL, Redis, RabbitMQ, Keycloak, `KafkaSettings`, etc.)                                                                                                                    |
| `Csnp.SharedKernel.Observability`  | Serilog structured logging, OpenTelemetry + Prometheus exporter, health checks                                                                                                                                                                                            |
| `Csnp.Contracts`                   | All cross-service integration event DTOs (no external NuGet dependencies)                                                                                                                                                                                                 |
| `Csnp.EventBus`                    | MassTransit + RabbitMQ abstractions: `IIntegrationEventPublisher`, `IIntegrationHandler<T>`, `ConfigureCsnpConsumerEndpoint()`                                                                                                                                            |
| `Csnp.Presentation.Common`         | `BaseV1Controller`, `ApiResponse<T>`, `ApiResponseFactory`, `ErrorHandlingMiddleware`, CORS, Swagger; `CommonServiceExtensions`, `CommonPipelineExtensions`                                                                                                               |
| `Csnp.Security.Infrastructure`     | `AddKeycloakJwtAuthentication()` — Keycloak JWT Bearer configuration                                                                                                                                                                                                      |

---

## Messaging Architecture

### RabbitMQ — Two Patterns (Critical Distinction)

**Pattern 1 — Full Outbox/Inbox (Wallet only):**

1. Domain event → `DomainToIntegrationDispatcher` → DB outbox table
2. `OutboxPublisherWorker` publishes to RabbitMQ (and Kafka, fire-and-forget)
3. MassTransit Consumer stores message in DB inbox table
4. `InboxProcessorWorker` reads inbox → dispatches as MediatR commands (guarantees ordering for 4-leg trade settlement)

**Pattern 2 — Outbox + Direct Consumer (Payment, Trading, Payout, Ledger):**

- Outbox for publishing (steps 1–2 above)
- Consumers handle events directly — no InboxProcessorWorker
- Idempotency via: `TryInsertAsync ON CONFLICT DO NOTHING` (DB-level constraint)

**`DomainToIntegrationDispatcher`** — per-service class in `Application/Dispatcher/` mapping domain events → outbox-stored integration events. Bridge between domain and messaging layers.

### Kafka — Shadow Streaming

Kafka runs **in parallel with RabbitMQ** as a shadow stream. A Kafka failure never affects RabbitMQ flow.

- **Producer:** `IKafkaEventPublisher` / `KafkaEventPublisher` in `Csnp.SharedKernel.Infrastructure`. Registered via `AddKafkaProducer()`. `OutboxPublisherWorker` calls it after successful RabbitMQ publish (fire-and-forget).
- **Message key:** `aggregateId` — ensures per-aggregate ordering within a partition.
- **Message header:** `EventType` — fully-qualified type name, used by the Go consumer (and `Csnp.Wallet.Consumer`) to route without deserializing the payload.
- **Topic:** `wallet.events` (configurable via `LOC_WALLET_KAFKA__TOPIC`)
- **Config:** `KafkaSettings` (BootstrapServers, Topic, SecurityProtocol, SaslMechanism, credentials)

**`Csnp.Wallet.Consumer`** — standalone C# Kafka consumer application:

- Consumer group: `csnp-wallet-shadow-consumer`
- Manual offset commit (`enable.auto.commit=false`), earliest offset reset
- Reads `wallet.events` topic; routes messages by `EventType` header
- Runs as a separate deployable container (13th container in the fleet)
- Config prefix: `LOC_WALLET_KAFKA__*`

### Integration Events (`Csnp.Contracts`)

| Category | Events                                                                                                                                                                                                                                                                                                       |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Users    | `UserSyncedIntegrationEvent`                                                                                                                                                                                                                                                                                 |
| Payments | `PaymentCompletedIntegrationEvent`, `PaymentFailedIntegrationEvent`                                                                                                                                                                                                                                          |
| Wallets  | `WalletWithdrawnIntegrationEvent`, `WalletTopUpCompletedIntegrationEvent`, `WalletDebitedForTransferIntegrationEvent`, `WalletCreditedFromTransferIntegrationEvent`, `TransferFailedIntegrationEvent`, `TransferRefundedIntegrationEvent`, `PayoutSucceededIntegrationEvent`, `PayoutFailedIntegrationEvent` |
| Trading  | `TradeMatchedIntegrationEvent`, `TradeSettledIntegrationEvent`, `TradingAccountDepositedIntegrationEvent`                                                                                                                                                                                                    |

All events extend `IntegrationEvent` (Id: Guid, OccurredOn: DateTime).

### Saga — Withdrawal Flow

```
Wallet.WithdrawCommand → WalletWithdrawnIntegrationEvent (via Outbox)
    → Payout.WalletWithdrawnConsumer
        → IPayoutProvider.ExecuteAsync
        → SUCCESS:  PayoutSucceededIntegrationEvent (via Payout Outbox)
        → FAILURE:  PayoutFailedIntegrationEvent   (via Payout Outbox)
        → TIMEOUT:  status → UNKNOWN → UnknownPayoutReconciliationJob polls provider
    → Wallet.PayoutSucceededConsumer → ConfirmWithdrawalCommand
    → Wallet.PayoutFailedConsumer   → RejectWithdrawalCommand
```

### Saga — Trade Settlement (4-Leg)

```
TradeMatchedIntegrationEvent → Wallet.InboxProcessorWorker (ordered execution):
    Leg 1: DebitForTradeCommand  (buyer,  quoteAsset, QuoteAmount)
    Leg 2: CreditFromTradeCommand(buyer,  baseAsset,  Quantity)
    Leg 3: DebitForTradeCommand  (seller, baseAsset,  Quantity)
    Leg 4: CreditFromTradeCommand(seller, quoteAsset, QuoteAmount)
→ PublishTradeSettledCommand → TradeSettledIntegrationEvent (via Outbox)
→ Trading.TradeSettledConsumer → release reserved balance + adjust totals
```

### Synchronous HTTP Calls

- **Payment → Wallet:** `WalletServiceClient` — credits wallet after payment completes
- **Trading → Wallet:** `IWalletServiceClient.DebitForTradingDepositAsync` → `POST /v1/wallet/{walletId}/debit-for-trading`, forwards user JWT
    - Polly **circuit breaker:** 5 failures → open for **5 seconds** (intentionally short for fast dev recovery)
    - Polly **retry:** 3 attempts with linear backoff (100ms, 200ms, 300ms)
    - `BrokenCircuitException` → `WalletServiceException(503)`
- **Trading internal:** `IBalanceReservationService` — raw SQL atomic operations on `trading.balances` (not an HTTP call)

---

## Service Details

### Wallet

**Commands (12):** `CreateWalletCommand`, `CompleteTopUpCommand`, `FailTopUpCommand`, `WithdrawCommand`, `ConfirmWithdrawalCommand`, `RejectWithdrawalCommand`, `DebitForTransferCommand`, `CreditFromTransferCommand`, `RefundTransferCommand`, `DebitForTradeCommand`, `CreditFromTradeCommand`, `PublishTradeSettledCommand`

**Queries:** `GetWalletBalanceQuery`, `GetMyWalletsQuery`, `GetWalletTransactionsQuery`, `GetTransferStatusQuery`, `VerifyWalletOwnerQuery`

**Consumers (all write to Inbox):** `UserSyncedConsumer`, `PaymentCompletedConsumer`, `PaymentFailedConsumer`, `WalletDebitedConsumer`, `PayoutSucceededConsumer`, `PayoutFailedConsumer`, `TradeMatchedConsumer`

**Background Workers:**

- `InboxProcessorWorker` — processes Inbox messages as MediatR commands; ensures ordered 4-leg trade settlement
- `OutboxPublisherWorker` — publishes Outbox events to RabbitMQ + Kafka (Kafka is fire-and-forget shadow)
- `StuckWithdrawalRecoveryJob` — **alert-only, never auto-releases** `LockedBalance`; detects wallets with `LockedBalance > 0` and no Confirm/Reject sentinel after 2 hours; emits `LogCritical` for manual ops intervention (auto-release would risk double-spend)

**Domain Entities:**

- `Wallet` (`AuditableEntity<long>`, `IAggregateRoot`) — `UserId`, `Status`, `Balance`, `LockedBalance`; methods: `CreditBalance()`, `DebitBalance()`, `ForceCreditBalance()`, `Reserve()`, `Release()`
- `Transaction` — saga correlation record; tracks top-ups, transfers, withdrawals, trades; `IsSentinel = true` on idempotency rows (excluded from daily/monthly limit calculations)
- `WalletLimit` — enforces daily/monthly withdrawal limits

**Domain Events (11):** `WalletCreditedDomainEvent`, `WalletTopUpCompletedDomainEvent`, `WalletTopUpFailedDomainEvent`, `WalletDebitedForTransferDomainEvent`, `WalletCreditedFromTransferDomainEvent`, `WalletWithdrawnDomainEvent`, `WalletDebitedForTradeDomainEvent`, `WalletCreditedFromTradeDomainEvent`, `TransferFailedDomainEvent`, `TransferRefundedDomainEvent`, `TradeSettledDomainEvent`

**DI Extensions:** `AddApplication()`, `AddInfrastructure()`, `AddWalletIdempotency()` (Redis), `AddWalletMessaging()` (MassTransit consumers), `AddKafkaProducer()` (shadow Kafka publish)

---

### Payment

**Command:** `TopUpCommand` — creates payment session; webhook events drive completion via `CompleteTopUpCommand` / `FailTopUpCommand` dispatched to Wallet.

**Providers:** PayPal (sandbox), Stripe — via `IPaymentProvider` / `IPaymentProviderFactory`

**Webhooks (idempotency via `RedisWebhookIdempotencyStore`):**

- `POST /api/v1/webhooks/paypal` — `PayPalWebhookController`
- `POST /api/v1/webhooks/stripe` — `StripeWebhookController`

**Domain Entity:** `Transaction` (`DomainEntity<long>`, `IAggregateRoot`) — `WalletId`, `Amount`, `ProviderId`, `ExternalOrderId`, `Status`; methods: `Create()`, `CompleteTransaction()`, `FailTransaction()`

**DI Extensions:** `AddApplication()`, `AddInfrastructure()`, `AddWalletClient(config)`, `AddPayPal(config)`, `AddStripe(config)`

---

### Trading

**Commands:**

- `PlaceOrderCommand` — idempotency check → market rule validation → fund reservation → persist → enqueue to engine via `OrderPlacedDomainEvent`
    - Market BUY: walks ask depth via `IMatchingEngine.GetDepth()` to calculate exact quote cost before reserving
    - Symbol derivation: if `BaseAsset`/`QuoteAsset` not supplied, derived from symbol (`symbol[..3]` / `symbol[3..]`); symbol must be ≥ 6 chars
    - On persist failure after reservation: auto-releases reservation (prevents permanent fund lock)
- `CancelOrderCommand` — marks order Cancelled in DB → raises `OrderCancelledDomainEvent`; returns `bool` (false → 404)
- `DepositToTradingAccountCommand` — Step 1: HTTP debit Wallet (idempotent) → Step 2: credit `trading.balances.total_amount`

**Queries:** `GetMyTradingBalancesQuery`, `GetMarketRuleQuery`, `GetOrderBookQuery` (in-memory, no DB), `GetRecentTradesQuery`, `GetMyOrdersQuery`

**Domain Entities:**

- `Order` (`AuditableEntity<long>`, `IAggregateRoot`) — `UserId`, `Symbol`, `BaseAsset`, `QuoteAsset`, `OrderType`, `OrderSide`, `Price`, `Quantity`, `RemainingQuantity`, `Status`, `IdempotencyKey`; methods: `Create()` (factory + validation), `Rehydrate()` (bypass validation), `Fill(qty)`, `Cancel()`
- `Trade` — immutable matched trade record: `BuyOrderId`, `SellOrderId`, `Symbol`, `Price`, `Quantity`, `Total`, `ExecutedAt`
- `MarketRule` — `TickSize`, `LotSize`, `MinNotional` per symbol

**Domain Events:** `OrderPlacedDomainEvent` → `OrderPlacedHandler` (enqueues to engine), `OrderCancelledDomainEvent` → `OrderCancelledHandler` (removes from book), `TradeMatchedDomainEvent`

**Domain Exceptions:** `InsufficientBalanceException` (from `IBalanceReservationService`) → HTTP 422; `WalletServiceException` (wraps Polly/HTTP errors) → HTTP 503

**Engine Layer (`Csnp.Trading.Engine`):**

```
src/Trading/Csnp.Trading.Engine/
├── Matching/MatchingEngine.cs       # BackgroundService; Channel<T>-based single-threaded loop
├── Matching/MatchResult.cs
├── OrderBook.cs                     # In-memory order book per symbol
├── BookEntry.cs
└── Interfaces/
    ├── IOrderRehydrationSource.cs
    ├── ITradeEventDispatcher.cs
    └── ITradingHubContext.cs        # SignalR abstraction (no ASP.NET dep in Engine)
```

- Algorithm: price-time priority, maker price wins
- Self-trade prevention: buyer == seller → skip match, order rests in book
- Thread safety: `Channel<T>` single loop — no locks on order books
- Restart recovery: `RehydrateAsync()` reloads open orders from DB on startup
- Partial fills: resting order decrements `RemainingQuantity`, stays until fully filled or cancelled
- `GetDepth(symbol, levels)` — O(N) in-memory snapshot, no DB round-trip

**`IMatchingEngine`** (Application abstraction, implemented by `MatchingEngine`):

- `PlaceOrderAsync(msg)` — non-blocking channel write; order already persisted before this call
- `CancelOrderAsync(msg)` — non-blocking channel write; order already marked Cancelled in DB
- `GetDepth(symbol, levels)` — synchronous in-memory snapshot, returns `(Bids, Asks)` tuples

**`TradeEventDispatcher`** — per match, single DB transaction:

1. INSERT trade record
2. UPDATE buy order (remaining quantity + status)
3. UPDATE sell order (remaining quantity + status)
4. INSERT outbox message (`TradeMatchedIntegrationEvent`)
5. COMMIT → Push `OrderBookUpdated` + `TradeExecuted` via SignalR (post-commit, best-effort)

**SignalR (`/hubs/trading`):**

- Groups: `market:{SYMBOL}` (e.g. `market:BTCUSDT`)
- Events: `"OrderBookUpdated"` (full depth snapshot), `"TradeExecuted"` (individual trade)
- Push failures are best-effort — logged as Warning, never roll back the trade transaction

**DI Registration (critical split):**

| Extension                 | Registered in   | Purpose                                                                          |
| ------------------------- | --------------- | -------------------------------------------------------------------------------- |
| `AddInfrastructure()`     | API + Worker    | DB context, repositories, balance reservation, event dispatchers                 |
| `AddMatchingEngine()`     | **API only**    | Singleton `MatchingEngine` + `ITradeEventDispatcher` + `IOrderRehydrationSource` |
| `AddWalletClient(config)` | **API only**    | `IWalletServiceClient` with Polly policies                                       |
| `AddTradingMessaging()`   | **Worker only** | MassTransit consumer for `TradeSettledIntegrationEvent`                          |

> **Critical:** `AddMatchingEngine()` must ONLY be called from the API host. Registering it in the Worker creates an isolated in-memory book per pod — trades will never match across processes.

**API Controllers:**

- `MarketRuleController` — `GET /api/v1/market-rule/{symbol}` → `MarketRuleDto` — `[AllowAnonymous]`
- `TradingAccountController` — `POST /api/v1/trading-account/deposit` (204), `GET /api/v1/trading-account/balance` (200)
- `OrderController`:
    - `POST /api/v1/order` → 202 Accepted + `PlaceOrderResponse(orderId)`
    - `DELETE /api/v1/order/{orderId}` → 204 / 404
    - `GET /api/v1/order/book?symbol=&levels=20` → `OrderBookDto` — `[AllowAnonymous]`
    - `GET /api/v1/order/trades?symbol=&limit=50` → `IReadOnlyList<TradeDto>` — `[AllowAnonymous]`
    - `GET /api/v1/order/my` → `IReadOnlyList<OrderDto>`

---

### Payout

**Consumer:** `WalletWithdrawnConsumer` — direct (no Inbox), uses DB-level idempotency (`TryInsertAsync ON CONFLICT DO NOTHING`)

**Domain Entity:** `Payout` (`DomainEntity<long>`, `IAggregateRoot`) — `TransactionId` (saga correlation), `WalletId`, `Amount`, `Currency`, `Destination`, `Status` (Pending → Processing → Succeeded/Failed/Unknown); methods: `Create()`, `UpdateToProcessing()`, `Succeed()`, `Fail()`, `MarkUnknown()`

**Provider:** `MockPayoutProvider` (current implementation of `IPayoutProvider`)

**Recovery Workers:**

- `StuckPayoutRecoveryJob` — detects PROCESSING rows > 5 min threshold → transitions to UNKNOWN
- `UnknownPayoutReconciliationJob` — polls provider status with exponential backoff + jitter, **no max retry limit**; resolves to SUCCEEDED/FAILED and writes to Outbox atomically

**DI Extensions:** `AddApplication()`, `AddInfrastructure()`, `AddPayoutMessaging()`

---

### Ledger

**Command:** `PostTransactionCommand` — posts a double-entry transaction with debit/credit entries

**Queries:** `GetAccountBalanceQuery`, `GetAccountEntriesQuery`, `GetTransactionByIdQuery`

**Consumers (direct, no Inbox):** `PaymentCompletedConsumer`, `PayoutSucceededConsumer`, `TradingAccountDepositedConsumer`, `WalletCreditedFromTransferConsumer` — all extend `LedgerPostingConsumerBase`; use `LedgerAccountCodeFactory` + `LedgerDateTimeHelper` helpers

**Domain Aggregates:** `Account`, `Entry` (`EntryRequest` value object), `Transaction`

**Domain Enums:** `AccountType`, `EntryType` (Debit/Credit), `EntryStatus` (Pending/Posted/Reversed), `TransactionType` (Deposit/Withdrawal/Transfer/Trade), `TransactionStatus` (Pending/Settled/Failed)

**Infrastructure:** `AccountReadRepository`, `AccountWriteRepository`, `TransactionReadRepository`, `TransactionWriteRepository`; `AccountService` implementing `IAccountService`

---

## Database Design

- **Single PostgreSQL instance**, schema-isolated per service: `wallet`, `payment`, `ledger`, `trading`, `payout`
- Each service has its own `DbContext` with `.HasDefaultSchema()` and snake_case column naming
- Separate migration history tables per service to avoid conflicts
- Migrations in dedicated projects: `migrations/Csnp.Migrations.<Service>/`
- **xmin optimistic concurrency** (Wallet + Trading) — PostgreSQL-native, no `RowVersion` column needed
- **Sentinel rows** (`IsSentinel = true`) — idempotency transaction rows in Wallet excluded from daily/monthly withdrawal limit calculations

---

## Configuration & Environment

**Location:** `_environment/<service>.env`

**Convention:** `LOC_<SERVICE>_<COMPONENT>__<PROPERTY>`

```
LOC_WALLET_RABBITMQ__HOST=docker-local
LOC_WALLET_DATABASE__HOST=localhost
LOC_WALLET_DATABASE__COMMANDTIMEOUT=10
LOC_WALLET_DATABASE__MINPOOLSIZE=5
LOC_WALLET_DATABASE__MAXPOOLSIZE=200
LOC_WALLET_REDIS__HOST=docker-local
LOC_WALLET_REDIS__PORT=6379
LOC_WALLET_KAFKA__BOOTSTRAPSERVERS=broker:9092
LOC_WALLET_KAFKA__TOPIC=wallet.events
```

**Import scripts:** `_environment/import-env.ps1` (PowerShell), `_environment/import-env.cmd` (CMD)

**Typed settings** bound via `AddCsnpConfigurations(config, "LOC_<SERVICE>")`: PostgreSQL (with connection pool + timeout settings), Redis, RabbitMQ, Keycloak, Vault, Kafka, OTLP endpoint.

---

## Testing

**23 test projects** — 3 per service (Unit, Integration, Architecture) × 6 + 5 shared.

| Type             | Purpose                                            | Frameworks                     |
| ---------------- | -------------------------------------------------- | ------------------------------ |
| **Unit**         | Isolated logic; Wallet and Payment have real cases | xUnit + Moq + FluentAssertions |
| **Integration**  | Real database                                      | xUnit + FluentAssertions       |
| **Architecture** | Dependency rule enforcement                        | xUnit + NetArchTest            |

**Shared test projects (5):** `Csnp.Presentation.Common.Tests.Unit`, `Csnp.SharedKernel.Application.Tests.Unit`, `Csnp.SharedKernel.Configuration.Tests.Unit`, `Csnp.SharedKernel.Infrastructure.Tests.Unit`, `Csnp.SeedWork.Tests.Unit`

---

## Error Handling & Domain-Driven Contracts

### Domain Errors

**`IDomainError` interface:**

```csharp
public interface IDomainError
{
    string Code { get; }
    string Message { get; }
}
```

**`DomainException` implements `IDomainError`:**

```csharp
public class DomainException : Exception, IDomainError
{
    public string Code { get; }
    public string Message { get; }
}
```

### HTTP Status Mapping

**ErrorHandlingMiddleware** maps domain errors to structured HTTP responses:

| Status                       | Condition                              | Examples                                                                                 |
| ---------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------- |
| **400 Bad Request**          | Validation or input errors             | (reserved for future use)                                                                |
| **409 Conflict**             | Concurrency conflicts                  | `DbUpdateConcurrencyException` (xmin mismatch)                                           |
| **422 Unprocessable Entity** | Business rule violation                | `InsufficientBalanceException`, `ValidationException` (FluentValidation)                 |
| **502 Bad Gateway**          | Upstream service unavailable           | `HttpRequestException`, `TaskCanceledException` in WalletServiceClient (Payment/Trading) |
| **503 Service Unavailable**  | Circuit breaker open or internal error | `WalletServiceException` (Polly circuit open, wrapped HTTP failures)                     |

### Transient Database Errors

**`TransientDbException`** wraps PostgreSQL transient states (SQLSTATE 40001, 40P01):

- **40001 — Serialization Failure:** Conflicting transactions at SERIALIZABLE or REPEATABLE READ isolation. Polly retries automatically with fresh transaction.
- **40P01 — Deadlock Detected:** Lock ordering conflict. Polly retries with fresh transaction, different lock ordering often resolves immediately.

Polly ResiliencePipeline configured with exponential backoff + jitter (max 3 retries) for both `ConcurrencyConflictException` and `TransientDbException`.

---

## CI/CD

### GitHub Actions (`.github/workflows/`) — Standard

- `ci.yml` — Reusable pipeline: build → Docker push → GitOps update (ArgoCD Kustomize `newTag`)
- **12 service-specific workflows** (1 API + 1 Worker per service), triggered on path changes; auto-detect supports `api`, `worker`, and `consumer` job types
- Registry: Docker Hub (`docker.io/skgc`), image tag: `skgc/csnp-<service>:<env>-<run_number>`
- Environments: `dev` → `uat` → `pro` (manual approval gate at UAT and production)

### Jenkins (`Jenkinsfile`) — Legacy

1. Auto-detect service from job name: `csnp-<module>-<type>` (types: `api`, `worker`, `consumer`)
2. Manual approval gate for UAT and production
3. Build → Push to Harbor (`harbor-dev.csnp.xyz`)
4. Update GitOps repo (Kustomize `newTag`)
5. Vault integration for secrets

### CI/CD Hardening

- **Docker Login to Harbor:** Deploy pipeline now authenticates to Harbor before pulling migrator image (prevents auth failures in secure registries).
- **Migrator Skip Logic:** Build skips migrator build + DB migration when migration files are unchanged (improves deploy speed for non-schema changes).
- **Latest Tag Push:** Images pushed with both versioned tag (e.g., `dev-123`) and `latest` tag for easy rollback reference.
- **BuildKit Cache Mounts:** Dockerfile optimized with BuildKit cache mounts for `apt` and `nuget` (speeds up layer caching, reduces network I/O).
- **Wallet Migrator Hardened:** Improved error handling, cleanup (`docker logout`, `rmi`, `git clone --depth 1`).

---

## Naming Conventions

| Artifact           | Pattern                            | Example                                   |
| ------------------ | ---------------------------------- | ----------------------------------------- |
| Projects           | `Csnp.<Context>.<Layer>`           | `Csnp.Wallet.Application`                 |
| Commands           | `<Action>Command`                  | `WithdrawCommand`                         |
| Queries            | `Get<Entity><Property>Query`       | `GetWalletBalanceQuery`                   |
| Handlers           | `<Command/Event>Handler`           | `WithdrawCommandHandler`                  |
| Validators         | `<Command>Validator`               | `WithdrawCommandValidator`                |
| Domain Events      | `<Entity><Action>DomainEvent`      | `WalletWithdrawnDomainEvent`              |
| Integration Events | `<Entity><Action>IntegrationEvent` | `PaymentCompletedIntegrationEvent`        |
| Consumers          | `<Event>Consumer`                  | `PaymentCompletedConsumer`                |
| Dispatchers        | `DomainToIntegrationDispatcher`    | per-service, in `Application/Dispatcher/` |

---

## Reference Documentation (`docs/`)

| File                         | Contents                                 |
| ---------------------------- | ---------------------------------------- |
| `architecture.md`            | High-level design and solution structure |
| `domain-structure.md`        | DDD layer breakdown                      |
| `domain-layer-comparison.md` | SeedWork vs SharedKernel comparison      |
| `event-driven-design.md`     | Outbox/Inbox/Saga patterns               |
| `cqrs-pattern.md`            | CQRS implementation                      |
| `class-design.md`            | Class and object design guidelines       |
| `shared-db-schema.md`        | Database schema strategy                 |
| `restful-api-guideline.md`   | API design standards                     |
| `dotnet-format-guide.md`     | Code formatting rules                    |
| `git-iso-process.md`         | Git branching and workflow               |
