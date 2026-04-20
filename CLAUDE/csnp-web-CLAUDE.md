# CSNP Web UI — Claude Code Reference

## Project Overview

**CSNP UI Web** is a Next.js frontend for the CSNP (Cross-Sector Network/Payment) platform. Users can:

- Authenticate via Keycloak (OpenID Connect / OAuth 2.0)
- Manage digital wallets (balance, transaction history, P2P transfers, top-ups, withdrawals)
- Trade on a real-time order book (SignalR + candlestick charts)
- Check KYC/AML compliance status per wallet
- Switch between English and Vietnamese (default: Vietnamese)

## Tech Stack

| Layer           | Technology                                        |
| --------------- | ------------------------------------------------- |
| Framework       | Next.js (App Router) + React 19                   |
| Language        | TypeScript (strict mode)                          |
| Auth            | NextAuth 4 + Keycloak (OpenID Connect)            |
| Styling         | Tailwind CSS 4 + PostCSS (`@tailwindcss/postcss`) |
| i18n            | i18next + react-i18next (vi default, en fallback) |
| Real-time       | @microsoft/signalr (WebSocket/SSE)                |
| Charts          | lightweight-charts (candlestick, 6 timeframes)    |
| Package manager | pnpm (frozen lockfile)                            |
| Build tool      | Next.js (Turbopack in dev)                        |
| Runtime         | Node.js 22.18.0                                   |

## Project Structure

```text
src/
├── app/
│   ├── api/
│   │   ├── auth/[...nextauth]/route.ts      # NextAuth config, JWT callbacks, token refresh
│   │   ├── config/route.ts                  # Public runtime config: keycloakIssuer, keycloakClientId, tradingHubUrl
│   │   └── proxy/[target]/[...path]/route.ts # Server-side proxy; hides backend URLs from browser
│   ├── layout.tsx                           # Root layout (fonts, RootLayoutClient)
│   ├── page.tsx                             # Home: landing (unauth) or wallet dashboard (auth)
│   ├── sign-in/page.tsx                     # Immediately triggers signIn("keycloak"), no UI
│   ├── sign-up/page.tsx                     # Manual PKCE → Keycloak /registrations
│   ├── payment/
│   │   ├── success/page.tsx                 # Post-payment polling (Stripe/PayPal)
│   │   └── cancel/page.tsx                  # Payment cancellation landing
│   ├── trading/page.tsx                     # Trading dashboard (~1,500 lines; all state in one file)
│   └── wallet/
│       ├── page.tsx                         # Wallet dashboard + transaction history
│       ├── topup/page.tsx                   # Top-up form (PayPal/Stripe)
│       ├── transfer/page.tsx                # P2P transfer form
│       └── withdraw/page.tsx                # Withdrawal form
├── components/
│   ├── AppHeader.tsx                        # Nav: logo, links, language switcher, two-step logout
│   └── trading/
│       └── CandlestickChart.tsx             # lightweight-charts candlestick, mock data, 6 timeframes
├── hooks/
│   ├── useAuthBootstrap.ts                  # Consumes AuthBootstrapContext → { ready, accessToken }
│   ├── useRuntimeConfig.ts                  # Fetches /api/config; module-level cache + stampede protection
│   ├── useTradingSignalR.ts                 # SignalR connect/subscribe/unsubscribe
│   └── useUserTimezone.ts                   # IANA timezone detection + locale-aware datetime formatting
├── providers/
│   └── RootLayoutClient.tsx                 # SessionProvider → SessionGuard → BootstrapProvider
├── services/
│   ├── user.service.ts                      # GET /v1/user/me (bootstrap sync)
│   ├── wallet.service.ts                    # Wallet + transaction APIs (retry on empty wallet)
│   ├── payment.service.ts                   # Top-up API
│   ├── trading.service.ts                   # Order book, orders, trades, deposit
│   └── compliance.service.ts                # GET /v1/wallets/{walletId}/compliance (passive, returns null on error)
├── lib/
│   ├── fetch-wrapper.ts                     # apiFetch() — centralized API client
│   └── server-env.ts                        # Server-only env reads + URL routing
├── types/
│   ├── wallet.ts                            # Wallet domain types
│   ├── trading.ts                           # Trading domain types
│   ├── compliance.ts                        # KycStatus, AmlStatus, ComplianceStatusDto
│   └── next-auth.d.ts                       # Session/JWT type augmentation
└── i18n/
    ├── settings.ts                          # i18next init (localStorage key "lang")
    └── locales/{en,vi}/common.json          # 200+ keys: home, wallet, trading, header sections
```

## Development Commands

```bash
pnpm dev             # Local dev (Turbopack, uses .env)
pnpm build           # Production build
pnpm start           # Production server (port 3000)
pnpm lint            # ESLint
pnpm format          # Prettier (write)
pnpm format:check    # Prettier (check only)
```

## Environment Configuration

Environment files live in `env/`. All variables are **server-side only** — backend URLs never reach the browser (proxy handles routing).

```bash
# Backend service URLs (server-side only)
CREDENTIAL_API_URL=https://api.csnp.xyz/credential/
WALLET_API_URL=https://api.csnp.xyz/wallet/
PAYMENT_API_URL=https://api.csnp.xyz/payment/
TRADING_API_URL=https://api.csnp.xyz/trading/
COMPLIANCE_API_URL=https://api.csnp.xyz/compliance/

# Keycloak (issuer + client ID exposed via /api/config)
KEYCLOAK_ISSUER=https://idp.csnp.xyz/realms/csnp
KEYCLOAK_CLIENT_ID=ui-web
KEYCLOAK_CLIENT_SECRET=<secret>
KEYCLOAK_SCOPE=openid profile email credential-scope payment-scope trading-scope wallet-scope compliance-scope

# NextAuth
NEXTAUTH_URL=https://app.csnp.xyz
NEXTAUTH_SECRET=<secret>
```

`tradingHubUrl` is derived from `TRADING_API_URL + "hubs/trading"` in `server-env.ts` — there is no separate env var for it.

## Authentication Architecture

### Flow

1. Unauthenticated visit to `/` → landing page with sign-in/sign-up
2. **Sign-in**: `/sign-in` immediately calls `signIn("keycloak")` (no UI) → Keycloak → callback → JWT cookie
3. **Sign-up**: Manual PKCE — 64-byte random verifier + SHA-256 challenge stored in `sessionStorage` under `next-auth.pkce.code_verifier` → redirect to Keycloak `/registrations` (not `/auth`) → `/api/auth/callback/keycloak` completes exchange
4. **Bootstrap**: Client calls `GET /v1/user/me`; triggers `update({ bootstrap: true })` if needed → server-side token refresh → `AuthBootstrapContext.ready = true` → business APIs activate
5. **Logout**: Two steps — `signOut({ redirect: false })` clears NextAuth cookie, then redirect to Keycloak `/protocol/openid-connect/logout?id_token_hint=...&post_logout_redirect_uri=...` destroys SSO session

### NextAuth JWT Callbacks

- **`jwt()`**: Stores tokens on first login; auto-refreshes with 30s expiry buffer; **skips refresh when `needsBootstrap=true`** (refreshing before bootstrap yields a token still missing `user_id`)
- **`session()`**: Exposes `accessToken`, `idToken`, `expiresAt`, `error`, `needsBootstrap` to client
- **`refreshAccessToken()`**: On failure sets `error = "RefreshAccessTokenError"`

### Bootstrap Provider (`src/providers/RootLayoutClient.tsx`)

Uses **module-level variables** (`bootstrapStarted`, `bootstrapCompleted`, `bootstrapToken`) instead of `useRef` so state survives React remounts during Next.js navigation. Three scenarios:

- **Scenario A**: New user — `needsBootstrap=true`, `user_id` missing from JWT → call `/me` → refresh token → ready
- **Scenario B**: Returning user — `needsBootstrap=false`, `user_id` present → call `/me` to verify → ready without refresh
- **Scenario C**: Stale token — `user_id` present but DB row deleted → `/me` returns `requiresTokenRefresh=true` → refresh → ready

### SessionGuard

Only calls `signOut()` on `session.error === "RefreshAccessTokenError"` (real refresh token expiry). Transient 401s never trigger logout.

## API Architecture

### Server-Side Proxy

All browser API calls route through `/api/proxy/{target}/{path}`.

- **Allowed targets**: `credential`, `wallet`, `payment`, `trading`, `compliance`
- **Forwarded headers**: `accept`, `accept-language`, `authorization`, `content-type`, `idempotency-key`, `x-correlation-id`
- **Response**: passes through `cache-control`, `content-type`; always adds `Cache-Control: no-store`

### API Client (`src/lib/fetch-wrapper.ts`)

`apiFetch(path, options, target)`:

- **Client-side**: routes to `/api/proxy/{target}`; **server-side**: calls backend URL directly
- Injects `Content-Type: application/json`, `x-correlation-id` (UUID per call), `Accept-Language`
- **401 retry**: Single retry with 300–500ms jitter to handle Keycloak/backend sync races; throws `UnauthorizedError` on persistent 401 (never auto-signs-out)
- **204 No Content**: Returns `null`
- **Error extraction**: Reads `.error`, `.message`, or `.errors` — `.errors` flattened from .NET validation format `{ Field: string[] }`

## Business APIs

| Service    | Method | Endpoint                                       | Notes                                                                            |
| ---------- | ------ | ---------------------------------------------- | -------------------------------------------------------------------------------- |
| Credential | GET    | `/v1/user/me`                                  | Bootstrap sync; returns `requiresTokenRefresh`                                   |
| Wallet     | GET    | `/v1/wallet/my`                                | Retries 4× with 0/500/1000/2000ms backoff (eventual consistency)                 |
| Wallet     | GET    | `/v1/transaction/{walletId}?page=X&pageSize=Y` | Offset pagination (default page=1, pageSize=10)                                  |
| Wallet     | POST   | `/v1/wallet/{walletId}/transfer`               | `{ transactionId, toAddress, amount }` — client-generated UUID                   |
| Wallet     | POST   | `/v1/wallet/{walletId}/withdraw`               | `{ transactionId, bankAccount, amount }` — client-generated UUID                 |
| Payment    | POST   | `/v1/payment/{walletId}/topup`                 | Returns `redirectUrl`; `transactionId` cached in sessionStorage                  |
| Trading    | GET    | `/v1/order/book?symbol=X&levels=N`             | Public; order book snapshot                                                      |
| Trading    | GET    | `/v1/order/trades?symbol=X&...`                | Cursor-based pagination; supports from/to date range, sort dir                   |
| Trading    | GET    | `/v1/marketrule/{symbol}`                      | `tickSize`, `lotSize`, `minNotional` for validation                              |
| Trading    | GET    | `/v1/order/my?page=X&pageSize=Y`               | Auth required; user's open orders                                                |
| Trading    | POST   | `/v1/order`                                    | `{ symbol, baseAsset, quoteAsset, side, type, price, quantity, idempotencyKey }` |
| Trading    | DELETE | `/v1/order/{orderId}`                          | `Idempotency-Key` header; per-order key stored in component state                |
| Trading    | GET    | `/v1/tradingaccount/balance`                   | Per-asset balances (available vs. reserved); paginated                           |
| Trading    | POST   | `/v1/tradingaccount/deposit`                   | Wallet → trading account; `{ walletId, asset, amount, idempotencyKey }`          |
| Compliance | GET    | `/v1/wallets/{walletId}/compliance`            | Returns `ComplianceStatusDto`; gracefully returns `null` on 404/error            |

## Key Domain Types

```ts
// wallet.ts
TransactionStatus: "Pending" | "Success" | "Failed";
TransactionType: "TopUp" | "TransferIn" | "TransferOut";
PaymentProvider: "PayPal" | "Stripe";

// trading.ts
OrderStatus: "Pending" | "Open" | "PartiallyFilled" | "Filled" | "Cancelled";

// compliance.ts
KycStatus: "NotStarted" | "Pending" | "Approved" | "Rejected";
AmlStatus: "Clear" | "Suspicious" | "Blocked" | "Review";
ComplianceStatusDto: {
    (walletId, userId, kycStatus, amlStatus, updatedAt, createdAt);
}
```

## Key Patterns

### Runtime Config

`useRuntimeConfig` fetches `/api/config` once, caches in a module-level variable, and uses a shared promise to prevent stampede. Provides `keycloakIssuer`, `keycloakClientId`, `tradingHubUrl` to all client components.

### Real-Time Trading

`useTradingSignalR` connects to the SignalR hub, subscribes via `Subscribe(symbol)`, and handles `OrderBookUpdated` / `TradeExecuted` events. Reconnect backoff: 0 / 2s / 5s / 10s / 30s. Trading page falls back to 5s polling when disconnected.

Trading page enforces market rules on order submission: tick size precision, lot size rounding (`roundToLotSize`), and min notional (`price × quantity >= minNotional`). Form fields (price ↔ quantity ↔ total) sync bidirectionally; percentage sliders offer 0/25/50/75/100% shortcuts.

### Payment Success Polling

Detects provider from URL params: `session_id` → Stripe (2s × 15), `token` → PayPal (4s × 20). Skips polls when tab is hidden. Fast path: reads `walletId` from `sessionStorage` (`tx_wallet:{txId}`) before falling back to full wallet scan.

### Timezone & Locale

`useUserTimezone()` detects IANA timezone via `Intl.DateTimeFormat().resolvedOptions()` (client-side only, avoids SSR mismatch). `formatTxDateTime(isoString, timezone, lang)` formats timestamps in user's timezone with offset label (e.g., GMT+7).

## State Management

No external state library.

| Mechanism              | Used for                                                           |
| ---------------------- | ------------------------------------------------------------------ |
| React Context          | `AuthBootstrapContext` (ready + accessToken), `SessionProvider`    |
| Module-level variables | Bootstrap state (survives remounts), runtime config cache          |
| `sessionStorage`       | PKCE verifier (`next-auth.pkce.code_verifier`), `tx_wallet:{txId}` |
| `localStorage`         | Language preference (`lang` key)                                   |

## Security

- **Server-side proxy**: Backend URLs never reach the browser
- **CSP** (`next.config.ts`): `default-src 'self'`; `script-src 'self' 'unsafe-inline' 'unsafe-eval'`; `connect-src 'self' https: http: ws: wss:`; `frame-ancestors 'none'`
- **`X-Frame-Options: DENY`**, **`X-Content-Type-Options: nosniff`**, **`Referrer-Policy: strict-origin-when-cross-origin`**
- **`Permissions-Policy`**: camera, microphone, geolocation disabled
- **PKCE** for sign-up (manual; verifier in sessionStorage)
- **JWT session** in HttpOnly + Secure cookies (production)
- **`x-correlation-id`** on every API request for tracing

## CI/CD & Deployment

### Jenkins (primary)

1. Detects environment from branch name
2. Manual approval gate for UAT/production
3. `docker build` with env file → pushes to Harbor registry (credentials from Vault)
4. Updates GitOps repo (`kustomization.yaml` image tag)

### GitHub Actions (secondary)

- `ci.yml`: Reusable build → push → GitOps update
- `csnp-web-ui.yml`: Service-specific caller with UAT/production approval gates

### Docker

- Multi-stage: `builder` (deps + `next build`) → `runner` (production deps only, `next start`)
- Base: `node:22.18.0-slim`; trusts custom CA for internal HTTPS; output: `standalone`; port `3000`

## Testing & Quality

No test framework (no Jest, RTL, Playwright, Cypress). ESLint + TypeScript strict mode are the primary quality gates.

## Path Alias

`@/*` → `./src/*` (configured in `tsconfig.json`).
