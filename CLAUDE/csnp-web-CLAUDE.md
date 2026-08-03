# CSNP Web UI — Claude Code Reference

## Project Overview

**CSNP UI Web** is a Next.js frontend for the CSNP (Core Services Network Platform) platform. Users can:

- Authenticate through a configurable OIDC provider (Keycloak or Cognito)
- Manage digital wallets (balance, transaction history, P2P transfers, top-ups, withdrawals)
- Trade on a real-time order book (SignalR + candlestick charts)
- Check KYC/AML compliance status per wallet
- Switch between English and Vietnamese (default: Vietnamese)

## Tech Stack

| Layer           | Technology                                        |
| --------------- | ------------------------------------------------- |
| Framework       | Next.js (App Router) + React 19                   |
| Language        | TypeScript (strict mode)                          |
| Auth            | NextAuth 4 + configurable OIDC provider           |
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
│   │   ├── config/route.ts                  # Public runtime config: authProvider, authIssuer, authClientId, auth endpoints, tradingHubUrl
│   │   └── proxy/[target]/[...path]/route.ts # Server-side proxy; hides backend URLs from browser
│   ├── layout.tsx                           # Root layout (fonts, RootLayoutClient)
│   ├── page.tsx                             # Home: landing (unauth) or wallet dashboard (auth)
│   ├── sign-in/page.tsx                     # Immediately triggers signIn(configured provider), no UI
│   ├── sign-up/page.tsx                     # Manual PKCE → provider registration endpoint
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
# BFF entrypoint for normal web flows
BFF_WEB_URL=http://localhost:8081

# External OIDC provider
AUTH_PROVIDER=keycloak
AUTH_ISSUER=https://idp.csnp.xyz/realms/csnp
AUTH_CLIENT_ID=ui-web
AUTH_CLIENT_SECRET=<secret>
AUTH_SCOPES=openid profile email bff-web-scope

# NextAuth
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=<secret>
```

`tradingHubUrl` is derived from `TRADING_API_URL + "hubs/trading"` to preserve the pre-BFF SignalR hub behavior. It must not use the BFF `/bff/api/v1` route prefix because the SignalR market-data hub is owned by Trading API, not the Web BFF.

## Authentication Architecture

### Flow

1. Unauthenticated visit to `/` → landing page with sign-in/sign-up
2. **Sign-in**: `/sign-in` immediately calls `signIn(configuredProvider)` (no UI) → external OIDC provider → callback → JWT cookie
3. **Sign-up**: Manual PKCE — 64-byte random verifier + SHA-256 challenge stored in `sessionStorage` under `next-auth.pkce.code_verifier` → redirect to the provider-specific registration endpoint → `/api/auth/callback/{provider}` completes exchange
4. **Bootstrap**: NextAuth exposes the access token; BFF protected business routes run csnp-identity onboarding server-side before downstream calls
5. **Logout**: Two steps — `signOut({ redirect: false })` clears the NextAuth cookie, then redirect to the configured provider logout endpoint to destroy the SSO session

### NextAuth JWT Callbacks

- **`jwt()`**: Stores tokens on first login; auto-refreshes with 30s expiry buffer
- **`session()`**: Exposes `accessToken`, `idToken`, `expiresAt`, `error` to client
- **`refreshAccessToken()`**: On failure sets `error = "RefreshAccessTokenError"`

### Bootstrap Provider (`src/providers/RootLayoutClient.tsx`)

Uses **module-level variables** (`bootstrapCompleted`, `bootstrapToken`) instead of `useRef` so state survives React remounts during Next.js navigation. It marks the app ready once NextAuth has an access token; identity onboarding is owned by BFF middleware.

### SessionGuard

Only calls `signOut()` on `session.error === "RefreshAccessTokenError"` (real refresh token expiry). Transient 401s never trigger logout.

## API Architecture

### BFF Rewrite

All browser API calls route through `/bff/{path}`, which Next.js rewrites to `BFF_WEB_URL/{path}`. The app no longer owns a per-service `/api/proxy/{target}` route.

### API Client (`src/lib/fetch-wrapper.ts`)

`apiFetch(path, options)`:

- **Client-side**: routes to `/bff/{path}`; **server-side**: calls `BFF_WEB_URL/{path}` directly
- Injects `Content-Type: application/json`, `x-correlation-id` (UUID per call), `Accept-Language`
- **401 retry**: Single retry with 300–500ms jitter to tolerate transient identity-propagation races; throws `UnauthorizedError` on persistent 401 (never auto-signs-out)
- **204 No Content**: Returns `null`
- **Error extraction**: Reads `.error`, `.message`, or `.errors` — `.errors` flattened from .NET validation format `{ Field: string[] }`

## Business APIs

| Service    | Method | Endpoint                                            | Notes                                                                            |
| ---------- | ------ | --------------------------------------------------- | -------------------------------------------------------------------------------- |
| Wallet     | GET    | `/api/v1/wallets`                                   | Retries only transient network/5xx failures                                      |
| Wallet     | GET    | `/api/v1/wallets/{walletId}/transactions?page=X...` | Offset pagination (default page=1, pageSize=10)                                  |
| Wallet     | POST   | `/api/v1/wallets/{walletId}/transfers`              | `{ transactionId, toAddress, amount }` - client-generated UUID                   |
| Wallet     | POST   | `/api/v1/wallets/{walletId}/withdrawals`            | `{ transactionId, bankAccount, amount }` - client-generated UUID                 |
| Payment    | POST   | `/api/v1/payments/topups`                           | Returns `redirectUrl`; `transactionId` cached in sessionStorage                  |
| Trading    | GET    | `/api/v1/markets/order-book?symbol=X&levels=N`      | Public; order book snapshot                                                      |
| Trading    | GET    | `/api/v1/markets/trades?symbol=X&...`               | Cursor-based pagination; supports from/to date range, sort dir                   |
| Trading    | GET    | `/api/v1/markets/{symbol}`                          | `tickSize`, `lotSize`, `minNotional` for validation                              |
| Trading    | GET    | `/api/v1/trading/orders?page=X&pageSize=Y`          | Auth required; user's open orders                                                |
| Trading    | POST   | `/api/v1/trading/orders`                            | `{ symbol, baseAsset, quoteAsset, side, type, price, quantity, idempotencyKey }` |
| Trading    | DELETE | `/api/v1/trading/orders/{orderId}`                  | `Idempotency-Key` header; per-order key stored in component state                |
| Trading    | GET    | `/api/v1/trading/balances`                          | Per-asset balances (available vs. reserved); paginated                           |
| Trading    | POST   | `/api/v1/trading/deposits`                          | Wallet to trading account; `{ walletId, asset, amount, idempotencyKey }`         |
| Compliance | GET    | `/api/v1/compliance/wallets/{walletId}`             | Returns `ComplianceStatusDto`; gracefully returns `null` on 404/error            |

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

`useRuntimeConfig` fetches `/api/config` once, caches in a module-level variable, and uses a shared promise to prevent stampede. Provides provider-neutral auth configuration and `tradingHubUrl` to client components.

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
