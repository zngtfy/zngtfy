# CSNP Admin UI — Claude Code Reference

## Project Overview

**CSNP Admin UI** is an Angular 21 frontend — a **1:1 port** of the Next.js app at
`D:\CSNP\Presentation\csnp-web` (same features, same business logic, same API contracts).

See `NEXTJS_SOURCE.md` for the full Next.js → Angular mapping guide and source file reference.

## Tech Stack

| Layer           | Technology                                             |
| --------------- | ------------------------------------------------------ |
| Framework       | Angular 21.2.x (standalone components)                 |
| Language        | TypeScript 6.0.x (strict mode)                         |
| Auth            | OpenID Connect / OAuth 2.0 with PKCE — client-side     |
| Styling         | Tailwind CSS 3.4.x + global `styles.css`               |
| Real-time       | Microsoft SignalR (`@microsoft/signalr` ^10)           |
| Charts          | `lightweight-charts` ^5.1.0                            |
| i18n            | `@ngx-translate/core` ^17 (`en` / `vi`, fallback `en`) |
| HTTP            | Angular `HttpClient` + functional interceptors         |
| State           | Angular Signals (`signal`, `computed`, `effect`)       |
| Package manager | pnpm                                                   |
| Runtime         | Node.js 22.x                                           |

## Development Commands

```bash
pnpm start          # Local dev (ng serve)
pnpm build          # Build (production)
pnpm watch          # Build watch mode
pnpm test           # Vitest unit tests
pnpm format         # Prettier
pnpm format:check   # Prettier check
```

## Key Conventions

- **Standalone components only** — no NgModule
- **Signals** for all component state — no `BehaviorSubject` in components
- **`inject()`** for dependency injection — no constructor injection
- **`@if` / `@for` / `@switch`** block syntax — not `*ngIf` / `*ngFor`
- **Functional interceptors** via `withInterceptors([...])`
- **Typed reactive forms** — `FormControl<string>`, `FormGroup<{...}>`
- **`input()` / `output()` / `viewChild()`** signal-based component I/O
- Path alias: `@/*` → `src/*` (configured in `tsconfig.json`)

---

## Codebase Summary

### Directory Structure

```text
src/app/
├── core/
│   ├── guards/           auth.guard.ts · role.guard.ts
│   ├── interceptors/     auth.interceptor.ts
│   └── services/         auth.service.ts · auth-bootstrap.service.ts
│                         runtime-config.service.ts · timezone.service.ts
│                         wallet.service.ts
│                         payment.service.ts · trading.service.ts
│                         trading-signalr.service.ts · compliance.service.ts
│                         role.service.ts · admin-user.service.ts
├── shared/
│   ├── header/           header.component.ts
│   ├── models/           auth.model.ts · runtime-config.model.ts
│   │                     wallet.model.ts · trading.model.ts · compliance.model.ts
│   │                     admin-user.model.ts
│   └── services/         local-storage.service.ts · session-storage.service.ts
├── auth/                 sign-in/ · sign-up/ · callback/
├── home/                 home.component.ts
├── wallet/               wallet.component.ts · topup/ · transfer/ · withdraw/
├── trading/              trading.component.ts · candlestick-chart/
├── payment/              success/ · cancel/
├── compliance/           compliance.component.ts · review/
├── user-management/      user-management.component.ts · create/
├── unauthorized/         unauthorized.component.ts
├── app.ts                AppComponent (root shell)
├── app.html
├── app.routes.ts
└── app.config.ts
public/
├── assets/runtime-config.json
└── i18n/en.json · vi.json
```

---

### Runtime Configuration

`public/assets/runtime-config.json` is fetched with `cache: 'no-store'` at startup via
`APP_INITIALIZER`. All services inject `RuntimeConfigService` to get base URLs.

```json
{
  "bffAdminApiUrl": "/api/",
  "tradingApiUrl": "https://api-dev.csnp.xyz/trading/",
  "authProvider": "keycloak",
  "authIssuer": "https://idp-dev.csnp.xyz/realms/csnp-local",
  "authClientId": "ui-admin",
  "authScope": "openid profile email bff-admin-scope"
}
```

`RuntimeConfigService.load()` validates required fields and normalizes trailing slashes.
The SignalR hub URL is derived from `tradingApiUrl` — no separate field needed.

---

### Bootstrap Flow (`app.config.ts`)

`APP_INITIALIZER` runs three steps in sequence before the app renders:

1. **`RuntimeConfigService.load()`** — fetch `runtime-config.json`
2. **`AuthService.initialize()`** — restore tokens from `sessionStorage`; auto-refresh if expired
3. **`AuthBootstrapService.bootstrap()`** — marks `ready = true` once an external identity-provider access token exists.
   Identity onboarding is handled by BFF protected business routes.

`AuthBootstrapService.ready` is a `signal<boolean>` backed by **module-level variables** so it
survives component recreation. `bootstrap()` sets `ready = true` even on error to prevent an app
hang. Components that need wallet/trading data gate their API calls behind
`if (!bootstrapService.ready()) return`.

---

### Authentication (`AuthService`)

Provider-neutral OAuth 2.0 Authorization Code flow with PKCE. **Tokens are stored in both in-memory signals and `sessionStorage`**
(persisted so page refreshes do not require re-login). PKCE `code_verifier` and `state` are
also in `sessionStorage` transiently.

| Signal / Method                 | Purpose                                                                     |
| ------------------------------- | --------------------------------------------------------------------------- |
| `isAuthenticated` (computed)    | `true` when token exists and not expired                                    |
| `userEmail` (computed)          | Decoded from JWT access token                                               |
| `accessToken` (signal)          | Raw JWT bearer token                                                        |
| `initialize()`                  | Restore tokens from sessionStorage; refresh if expired (idempotent)         |
| `redirectToLogin(callbackUrl?)` | Generate PKCE challenge → redirect to the configured authorization endpoint |
| `redirectToRegister()`          | Redirect to the configured registration endpoint                            |
| `handleCallback(code, state)`   | Exchange code for tokens; validates state; clears verifier                  |
| `refreshTokens()`               | POST to the configured token endpoint with `refresh_token`                  |
| `logout()`                      | Clear signals + sessionStorage → redirect to the configured logout endpoint |

**`AuthInterceptor`** (functional): adds `Authorization: Bearer …` + `x-correlation-id` (UUID v4)
on every request. On 401: single-flight refresh lock (one refresh at a time, others wait); retries
original request with new token. Persistent 401 throws `UnauthorizedError` — **never auto-navigates
from the interceptor**.

**`AuthGuard`** (`CanActivateFn`): awaits `authService.initialize()` then redirects to `/sign-in`
if not authenticated.

---

### Routes

All routes use lazy loading (`loadComponent`).

| Path                    | Component                 | Guard                                                                 |
| ----------------------- | ------------------------- | --------------------------------------------------------------------- |
| `/`                     | `HomeComponent`           | —                                                                     |
| `/sign-in`              | `SignInComponent`         | —                                                                     |
| `/sign-up`              | `SignUpComponent`         | —                                                                     |
| `/auth/callback`        | `CallbackComponent`       | —                                                                     |
| `/unauthorized`         | `UnauthorizedComponent`   | —                                                                     |
| `/trading`              | `TradingComponent`        | —                                                                     |
| `/wallet`               | `WalletComponent`         | `authGuard`                                                           |
| `/wallet/topup`         | `TopupComponent`          | `authGuard`                                                           |
| `/wallet/transfer`      | `TransferComponent`       | `authGuard`                                                           |
| `/wallet/withdraw`      | `WithdrawComponent`       | `authGuard`                                                           |
| `/payment/success`      | `SuccessComponent`        | `authGuard`                                                           |
| `/payment/cancel`       | `CancelComponent`         | `authGuard`                                                           |
| `/compliance`           | `ComplianceComponent`     | `authGuard, roleGuard([compliance_read_roles])`                       |
| `/compliance/:walletId` | `ReviewComponent`         | `authGuard, roleGuard([compliance_read_roles])`                       |
| `/users`                | `UserManagementComponent` | `authGuard, roleGuard(['csnp.backoffice_admin', 'csnp.super_admin'])` |
| `/users/create`         | `CreateUserComponent`     | `authGuard, roleGuard(['csnp.backoffice_admin', 'csnp.super_admin'])` |
| `**`                    | Redirect → `/`            | —                                                                     |

`/trading` is public — unauthenticated users see the page but a "log in to trade" prompt replaces
the order form.

---

### Services

| Service                 | Location           | Responsibility                                                         |
| ----------------------- | ------------------ | ---------------------------------------------------------------------- |
| `RuntimeConfigService`  | `core/services/`   | Load & provide runtime-config.json values                              |
| `AuthService`           | `core/services/`   | OIDC/OAuth tokens, redirect, refresh, logout                           |
| `AuthBootstrapService`  | `core/services/`   | `ready` signal, module-level state                                     |
| `RoleService`           | `core/services/`   | Parse `csnp.*` roles from JWT, role checking, computed RBAC properties |
| `AdminUserService`      | `core/services/`   | Admin user CRUD — list, create, update roles, delete                   |
| `WalletService`         | `core/services/`   | Wallets, transactions, transfer, withdraw                              |
| `PaymentService`        | `core/services/`   | `topUp()` → `POST /api/v1/payments/topups`                             |
| `TradingService`        | `core/services/`   | Order book, orders, trades, place/cancel, deposits                     |
| `TradingSignalRService` | `core/services/`   | SignalR hub connection, symbol subscriptions                           |
| `ComplianceService`     | `core/services/`   | AML alerts, KYC/compliance status, update KYC status                   |
| `TimezoneService`       | `core/services/`   | IANA timezone signal, `formatTxDateTime()`                             |
| `LocalStorageService`   | `shared/services/` | Typed localStorage wrapper (language key)                              |
| `SessionStorageService` | `shared/services/` | Typed sessionStorage wrapper (PKCE, tokens, tx_wallet)                 |

---

### Components

| Component                   | Route                   | Notes                                                                                |
| --------------------------- | ----------------------- | ------------------------------------------------------------------------------------ |
| `AppComponent`              | root shell              | `<app-header>` + `<router-outlet>`; restores i18n lang from localStorage             |
| `HeaderComponent`           | shared                  | Logo, nav links, language pill (en/vi), sign-out; RBAC-aware nav (compliance, users) |
| `HomeComponent`             | `/`                     | Auth: "Go to Wallet" + "Top Up" links. Unauth: split branding/sign-in layout         |
| `SignInComponent`           | `/sign-in`              | No form — auth users → `/`, unauth → `authService.redirectToLogin('/')`              |
| `SignUpComponent`           | `/sign-up`              | Auth users → `/`, unauth → `authService.redirectToRegister()`                        |
| `CallbackComponent`         | `/auth/callback`        | Exchanges PKCE code → tokens → bootstrap → navigate to `callbackUrl`                 |
| `UnauthorizedComponent`     | `/unauthorized`         | 403 error page for insufficient role                                                 |
| `TradingComponent`          | `/trading`              | Symbol selector, order book, candlestick chart, recent trades, order form, deposits  |
| `CandlestickChartComponent` | inside `/trading`       | `lightweight-charts` v5; timeframe selector (1m/5m/15m/1h/4h/1D); dark theme         |
| `WalletComponent`           | `/wallet`               | Wallet cards, transaction history, filter pills, pagination, timezone-aware dates    |
| `TopupComponent`            | `/wallet/topup`         | Amount + provider (PayPal/Stripe) selection → redirect to payment provider           |
| `TransferComponent`         | `/wallet/transfer`      | P2P transfer; idempotency key generated on init; success state with new balance      |
| `WithdrawComponent`         | `/wallet/withdraw`      | Withdrawal; same idempotency pattern as transfer                                     |
| `SuccessComponent`          | `/payment/success`      | Adaptive polling until balance updates; 10 s countdown redirect after confirm        |
| `CancelComponent`           | `/payment/cancel`       | Static: warning icon, "Try Again" / "Back to Wallet" links                           |
| `ComplianceComponent`       | `/compliance`           | AML alerts dashboard; status filter pills; paginated table (20/page); row → detail   |
| `ReviewComponent`           | `/compliance/:walletId` | KYC review detail; AML + KYC status badges; KYC status update form                   |
| `UserManagementComponent`   | `/users`                | Admin user list; pagination; edit roles; delete user (backoffice_admin only)         |
| `CreateUserComponent`       | `/users/create`         | Form to create new admin user with email, password, roles                            |

---

### Key Business Logic

**Wallet retry** — `WalletService.getMyWallets()` retries up to 4× with exponential backoff
(0 / 500 / 1000 / 2000 ms). Reason: backend eventual consistency after bootstrap creates the wallet.

**Idempotency** — `TransferComponent`, `WithdrawComponent`, and `TradingComponent` each generate
`crypto.randomUUID()` **once** on component init and reuse the same UUID on every retry so the
backend can deduplicate double-submits.

**Payment polling** — `SuccessComponent` detects the provider from query params (`session_id` →
Stripe, `token` → PayPal) and polls `getMyWallets()` at adaptive intervals:

| Provider | Interval | Max attempts |
| -------- | -------- | ------------ |
| Stripe   | 2 s      | 15           |
| PayPal   | 4 s      | 20           |
| default  | 3 s      | 20           |

Polling pauses when `document.hidden === true` (tab not visible). After confirmation a 10 s
countdown redirects to `/wallet`.

**Session storage (payment)** — on topUp success: `sessionStorage['tx_wallet:${transactionId}']
= walletId`. `SuccessComponent` reads this key to know which wallet to refresh.

**SignalR reconnect** — `TradingSignalRService` uses automatic reconnect with delays
`[0, 2000, 5000, 10000, 30000]` ms. Symbol subscriptions are restored after reconnect via
`Subscribe(symbol)` hub method.

**Market rule caching** — `TradingComponent` caches `MarketRuleDto` per symbol to avoid
repeated fetches on symbol switch.

**Language persistence** — `HeaderComponent.changeLanguage()` calls `translate.use(lang)`,
updates `document.documentElement.lang`, and writes to `localStorage['lang']`.
`AppComponent.ngOnInit` reads `localStorage['lang']` to restore preference.

**i18n cache-busting** — translation files are loaded as
`/i18n/{lang}.json?v={BUILD_HASH}` so browsers always fetch the latest strings after deploy.

---

### API Contracts

**Admin users** (`bffAdminApiUrl`)

```text
GET    /api/v1/admin/users?page&pageSize       →  AdminUserDto[]
GET    /api/v1/admin/users/{id}                →  AdminUserDtoApiResponse
POST   /api/v1/admin/users                     →  AdminUserDtoApiResponse
DELETE /api/v1/admin/users/{id}                →  void
PATCH  /api/v1/admin/users/{id}/roles          →  AdminUserDtoApiResponse
```

**Wallet** (`bffAdminApiUrl`)

```text
GET  /api/v1/wallets                                      →  WalletDto[]
GET  /api/v1/wallets/{walletId}/transactions?page&pageSize →  WalletTransactionPage
POST /api/v1/wallets/{walletId}/transfers                  →  { transactionId }
POST /api/v1/wallets/{walletId}/withdrawals                →  { transactionId }
```

**Payment** (`bffAdminApiUrl`)

```text
POST /api/v1/payments/topups                    →  { transactionId, redirectUrl }
```

**Trading REST** (`bffAdminApiUrl`)

```text
GET    /api/v1/markets/order-book?symbol&levels →  OrderBookDto
GET    /api/v1/trading/orders?page&pageSize     →  OrderPageDto
GET    /api/v1/markets/trades?symbol&...        →  TradeCursorPageDto
POST   /api/v1/trading/orders                   →  { orderId }
DELETE /api/v1/trading/orders/{orderId}         →  void
GET    /api/v1/markets/{symbol}                 →  MarketRuleDto
GET    /api/v1/trading/balances                 →  TradingBalancePageDto
POST   /api/v1/trading/deposits                 →  void
```

**Trading SignalR** hub at `{tradingApiUrl}/hubs/trading`

- Client listens: `OrderBookUpdated(OrderBookDto)`, `TradeExecuted(TradeDto)`
- Client invokes: `Subscribe(symbol)`, `Unsubscribe(symbol)`

**Compliance** (`bffAdminApiUrl`)

```text
GET   /api/v1/compliance/wallets/{walletId}     →  ComplianceStatusDto
GET   /api/v1/compliance/aml-alerts?status      →  PagedResponse<AmlAlertDto>
PATCH /api/v1/compliance/wallets/{walletId}/kyc/status →  void
```

---

### Models

```typescript
// auth.model.ts
interface MeResponse {
  userId: string;
  tokenUserId: string | null;
  requiresTokenRefresh: boolean;
}
interface TokenSet {
  accessToken: string;
  idToken: string;
  refreshToken: string;
  expiresAt: number;
}

// runtime-config.model.ts
interface RuntimeConfig {
  bffAdminApiUrl: string;
  tradingApiUrl: string;
  authProvider: AuthProvider;
  authIssuer: string;
  authClientId: string;
  authScope: string;
  authAuthorizationEndpoint: string;
  authTokenEndpoint: string;
  authLogoutEndpoint: string;
  authRegistrationEndpoint: string;
}

// wallet.model.ts
type PaymentProvider = 'PayPal' | 'Stripe';
type TransactionStatus = 'Pending' | 'Success' | 'Failed';
type TransactionType = 'TopUp' | 'TransferIn' | 'TransferOut';

interface WalletDto {
  walletId: string;
  balance: number;
  currency: string;
  status: string;
}
interface WalletTransaction {
  id: string;
  transactionId: string;
  amount: number;
  currency: string;
  type: TransactionType;
  status: TransactionStatus;
  metadata?: string;
  createdAt: string;
}
interface WalletTransactionPage {
  items: WalletTransaction[];
  totalCount: number;
  page: number;
  pageSize: number;
}
interface TransferRequest {
  transactionId: string;
  receiverWalletId: string;
  amount: number;
  currency: string;
}
interface WithdrawRequest {
  transactionId: string;
  destination: string;
  amount: number;
  currency: string;
}
interface TopUpRequest {
  amount: number;
  currency: string;
  provider: PaymentProvider;
}
interface TopUpResult {
  transactionId: string;
  redirectUrl: string;
}

// trading.model.ts
type OrderSide = 'Buy' | 'Sell';
type OrderType = 'Limit' | 'Market';
type OrderStatus = 'Pending' | 'Open' | 'PartiallyFilled' | 'Filled' | 'Cancelled';

interface PriceLevelDto {
  price: number;
  quantity: number;
}
interface OrderBookDto {
  symbol: string;
  bids: PriceLevelDto[];
  asks: PriceLevelDto[];
}
interface OrderDto {
  orderId: string;
  symbol: string;
  side: OrderSide;
  orderType: OrderType;
  price: number | null;
  quantity: number;
  remainingQuantity: number;
  status: OrderStatus;
  createdAt: string;
}
interface TradeDto {
  tradeId: string;
  symbol: string;
  price: number;
  quantity: number;
  total: number;
  createdAt: string;
}
interface PlaceOrderRequest {
  symbol: string;
  side: OrderSide;
  orderType: OrderType;
  price?: number;
  quantity: number;
  baseAsset: string;
  quoteAsset: string;
  idempotencyKey: string;
}
interface DepositToTradingAccountRequest {
  walletId: string;
  asset: string;
  amount: number;
  idempotencyKey: string;
}
interface TradingBalanceDto {
  asset: string;
  totalAmount: number;
  reservedAmount: number;
  availableAmount: number;
}
interface MarketRuleDto {
  symbol: string;
  tickSize: number;
  lotSize: number;
  minNotional: number;
}
interface OrderPageDto {
  items: OrderDto[];
  totalCount: number;
  page: number;
  pageSize: number;
}
interface TradeCursorPageDto {
  items: TradeDto[];
  nextCursor: string | null;
  hasMore: boolean;
}
interface TradingBalancePageDto {
  items: TradingBalanceDto[];
  totalCount: number;
  page: number;
  pageSize: number;
}

// compliance.model.ts
type KycStatus = 'NotStarted' | 'Pending' | 'Approved' | 'Rejected';
type AmlStatus = 'Clear' | 'Suspicious' | 'Blocked' | 'Review';

interface ComplianceStatusDto {
  walletId: string;
  userId: string;
  kycStatus: KycStatus;
  amlStatus: AmlStatus;
  updatedAt: string;
  createdAt: string;
}
interface AmlAlertDto {
  walletId: string;
  userId: string;
  amlStatus: AmlStatus;
  kycStatus: KycStatus;
  updatedAt: string;
}
interface UpdateKycStatusRequest {
  status: KycStatus;
}
interface PagedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

// admin-user.model.ts
interface AdminUserDto {
  id: string;
  email: string;
  displayName: string;
  enabled: boolean;
  roles: string[];
  createdAt: string;
}
interface AdminUserListResponse {
  success: boolean;
  message: string | null;
  data: AdminUserDto[];
}
interface AdminUserResponse {
  success: boolean;
  message: string | null;
  data: AdminUserDto;
}
interface CreateAdminUserCommand {
  email: string;
  password: string;
  displayName: string;
  roles: string[];
}
interface UpdateAdminUserRolesRequest {
  roles: string[];
}
type CsnpRole =
  | 'csnp.super_admin'
  | 'csnp.backoffice_admin'
  | 'csnp.compliance_admin'
  | 'csnp.risk_analyst'
  | 'csnp.finance_operator'
  | 'csnp.support_agent'
  | 'csnp.auditor';

export const CSNP_ROLES: readonly CsnpRole[] = [
  'csnp.super_admin',
  'csnp.backoffice_admin',
  'csnp.compliance_admin',
  'csnp.risk_analyst',
  'csnp.finance_operator',
  'csnp.support_agent',
  'csnp.auditor',
];
```
