# csnp-compliance — Claude Code context

## What this service does

CSNP Compliance bounded context (KYC / AML). Two binaries share the same
domain, repository, and handler packages:

| Binary     | Entry point            | Purpose                                                          |
| ---------- | ---------------------- | ---------------------------------------------------------------- |
| `api`      | `cmd/api/main.go`      | REST API — compliance status, AML alerts, back-office KYC update |
| `consumer` | `cmd/consumer/main.go` | Kafka consumer — routes wallet events to domain handlers         |

Both persist to MongoDB (`kyc_records` collection, keyed on `wallet_id`).

## Project layout

```
cmd/
  api/main.go          ← fx wiring: HTTP server, ComplianceController, KycRepository
  consumer/main.go     ← fx wiring: Kafka consumer, all event handlers, KycRepository
internal/
  config/config.go     ← KafkaConfig, MongoConfig, HttpConfig, CorsConfig, DocumentationConfig
  api/
    server.go          ← chi router, CORS, JWT middleware, /health route
    swagger.go         ← embedded Swagger UI + OpenAPI spec at /swagger/
    v1/
      compliance_controller.go  ← GET /v1/wallets/{id}/compliance, GET /v1/aml/alerts, PATCH /v1/wallets/{id}/kyc/status
    middleware/auth.go ← JWT validation via Keycloak JWKS; no-auth dev mode when JWKSURI is empty
    dto/compliance.go  ← ComplianceStatusResponse, AmlAlertResponse, PagedResponse[T], UpdateKycStatusRequest
  consumer/compliance_consumer.go  ← Kafka poll loop, event dispatch, graceful shutdown
  handler/
    kyc_handler.go           ← UserSynced → KycRecord(kyc=NotStarted, aml=Clear)
    aml_handler.go           ← WalletDebitedForTransfer → screen sender (P2P)
    aml_credit_handler.go    ← WalletCreditedFromTransfer → screen receiver (P2P)
    aml_withdrawal_handler.go← WalletWithdrawn → screen wallet (external withdrawal)
    aml_topup_handler.go     ← WalletTopUpCompleted → screen wallet (external inflow)
  repository/kyc_repository.go  ← MongoDB upsert, FindByWalletID, FindByAmlStatus, UpdateKycStatus
  domain/
    kyc.go   ← KycRecord struct, KycStatus enum
    aml.go   ← AmlAlert struct, AmlAlertStatus enum
```

## Tech stack

| Concern        | Library                                   |
| -------------- | ----------------------------------------- |
| HTTP router    | go-chi/chi v5                             |
| CORS           | go-chi/cors v1                            |
| JWT auth       | golang-jwt/jwt v5 + MicahParks/keyfunc v3 |
| Kafka          | segmentio/kafka-go v0.4                   |
| MongoDB        | mongo-driver v2                           |
| Logging        | uber/zap (≈ Serilog)                      |
| Config         | spf13/viper (≈ IOptions<T>)               |
| DI / lifecycle | uber/fx (≈ .NET DI + IHostedService)      |

## Environment variable convention

`LOC_COMPLIANCE_<COMPONENT>__<PROPERTY>` — double-underscore maps to `.` in
viper's key hierarchy. See `.env.example` for all variables.

Key variables:

```
LOC_COMPLIANCE_KAFKA__BOOTSTRAPSERVERS
LOC_COMPLIANCE_KAFKA__TOPIC
LOC_COMPLIANCE_KAFKA__GROUPID
LOC_COMPLIANCE_MONGO__URI
LOC_COMPLIANCE_MONGO__DATABASE
LOC_COMPLIANCE_HTTP__PORT          (default 5201)
LOC_COMPLIANCE_HTTP__JWKSURI       (empty = dev no-auth mode)
LOC_COMPLIANCE_CORS__ALLOWEDORIGINS
LOC_COMPLIANCE_DOCUMENTATION__ENABLESWAGGER
```

## API endpoints

All `/v1` routes require a valid Bearer JWT (unless JWKSURI is empty).

| Method | Path                                        | Description                             |
| ------ | ------------------------------------------- | --------------------------------------- |
| GET    | `/health`                                   | Liveness check — `{"status":"healthy"}` |
| GET    | `/v1/wallets/{walletId}/compliance`         | KYC + AML record for a wallet           |
| GET    | `/v1/aml/alerts?status=&page=1&pageSize=20` | Paged AML alert list                    |
| PATCH  | `/v1/wallets/{walletId}/kyc/status`         | Back-office: set KYC status             |
| GET    | `/swagger/`                                 | Swagger UI (embedded, no CDN)           |

## Kafka consumer design

- Manual offset commit — `CommitInterval: 0`.
- `StartOffset: kafka.FirstOffset` — replay from earliest on first start.
- Empty `BootstrapServers` → log warning and exit cleanly.
- Network errors → 5 s retry with graceful-shutdown check.
- Unknown event type → commit and skip (not an error).
- Handler error → offset NOT committed; message redelivered on restart.
- EventType resolved from `EventType` header first, raw key bytes as fallback.

## Kafka event handlers

| Handler              | EventType key (Csnp.Contracts.…)                     | Action                                              |
| -------------------- | ---------------------------------------------------- | --------------------------------------------------- |
| KycHandler           | `Users.UserSyncedIntegrationEvent`                   | Create/update record with kyc=NotStarted, aml=Clear |
| AmlHandler           | `Wallets.WalletDebitedForTransferIntegrationEvent`   | Screen P2P sender                                   |
| AmlCreditHandler     | `Wallets.WalletCreditedFromTransferIntegrationEvent` | Screen P2P receiver                                 |
| AmlWithdrawalHandler | `Wallets.WalletWithdrawnIntegrationEvent`            | Screen external withdrawal                          |
| AmlTopUpHandler      | `Wallets.WalletTopUpCompletedIntegrationEvent`       | Screen external inflow                              |

AML screening rule: amount ≥ $10,000 → `Review`; otherwise `Clear`.

## MongoDB idempotency

Collection: `kyc_records`, keyed on `wallet_id`.

- **`Upsert`** (KycHandler): full `$set` of all fields + `$setOnInsert(created_at)`.
  Owns `kyc_status`; does not clobber `aml_status` on replay.
- **`UpsertAmlStatus`** (all AML handlers): updates only `aml_status`, `updated_at`,
  `last_event`, `user_id`. Does NOT touch `kyc_status`. Creates a minimal record
  (kyc=NotStarted) if none exists yet.

## Domain enums

```go
KycStatus:      NotStarted | Pending | Approved | Rejected
AmlAlertStatus: Clear | Suspicious | Blocked | Review
```

## Running locally

```sh
cp .env.example .env   # populate vars

# API server
go run ./cmd/api

# Kafka consumer (separate terminal)
go run ./cmd/consumer

# Docker (build arg TARGET selects binary)
docker build --build-arg TARGET=api      -t csnp-compliance-api .
docker build --build-arg TARGET=consumer -t csnp-compliance-consumer .
```

Requires Docker with Kafka + MongoDB running.

## Adding a new event handler

1. Create `internal/handler/<name>_handler.go` — define payload struct, `EventType()` const, implement `consumer.EventHandler`.
2. `fx.Provide` the constructor in `cmd/consumer/main.go`.
3. Add the handler to `newEventHandlers()` in `cmd/consumer/main.go`.

## Reference .NET implementation

- Enums: `D:\CSNP\Application\csnp-fintech\src\Compliance\Csnp.Compliance.Domain\Enums\`
- Kafka consumer pattern: `D:\CSNP\Application\csnp-fintech\src\Wallet\Csnp.Wallet.Consumer\`
