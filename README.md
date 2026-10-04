# BankApp API Gateway — nginx / OpenResty

The single public entry point for BankApp. Terminates TLS, validates Keycloak JWTs at the edge in Lua, and reverse-proxies every request to the right internal service. Nothing else in the stack is exposed to the host — the browser only ever talks to this gateway on ports `80` and `443`.

Built on **OpenResty 1.25.3.2** (nginx + LuaJIT) with the `lua-resty-jwt` and `lua-resty-http` modules.

---

## What it does

```
Browser ──HTTPS :443──▶ nginx / OpenResty
                          ├─ /gateway/health         → 200 JSON (liveness)
                          ├─ = /product.html         → static spec document
                          ├─ /auth/*                 → Keycloak  (OIDC login, token endpoint)
                          ├─ /api/auth/*             → Next.js   (NextAuth callbacks)
                          ├─ /api/*   ──JWT verify──▶ Spring Boot (+ X-User-* headers)
                          └─ /*                      → Next.js   (frontend pages)
```

- **TLS termination** — self-signed cert for local dev (`certs/localhost.crt`), real cert in prod.
- **Edge JWT validation** — `lua/jwt_verify.lua` verifies the RS256 signature against Keycloak's realm public key (cached 1 h) on every `/api/*` request, then injects `X-User-Roles`, `X-User-Email`, `X-User-Sub`. Spring Boot trusts those headers and never parses a JWT itself.
- **Rate limiting** — `20 r/s` on `/api/*`, `5 r/s` on `/auth/*` (per client IP).
- **Structured access logs** — `lua/logger.lua` emits one JSON line per request tagged by type (`frontend` / `api` / `oidc` / `nextauth`).
- **HTTP → HTTPS redirect** and standard security headers (HSTS, X-Frame-Options, etc.).

---

## Request routing (`conf.d/bankapp.conf`)

| Location | Upstream | Notes |
|----------|----------|-------|
| `/gateway/health` | — | Returns `{"status":"ok","gateway":"openresty"}` |
| `= /product.html` | static | Serves the product spec from `/usr/share/nginx/html` |
| `/auth/` | `keycloak` | OIDC login page + token endpoint; rate-limited `5 r/s` |
| `/api/auth/` | `nextjs_frontend` | NextAuth routes — matched **before** `/api/` (more specific prefix wins) |
| `/api/` | `spring_backend` | JWT verified in Lua first; rate-limited `20 r/s` |
| `/` | `nextjs_frontend` | Everything else — frontend pages, WebSocket upgrade enabled |

### Proxy buffers for Auth.js

The `/`, `/api/auth/`, and `/auth/` locations raise the proxy buffers:

```nginx
proxy_buffer_size       128k;
proxy_buffers           4 256k;
proxy_busy_buffers_size 256k;
```

NextAuth v5 writes large encrypted session cookies (chunked `Set-Cookie` headers, ~5–10 KB) on every OIDC callback and protected-page render. nginx's default 4 KB header buffer overflows on these and returns **502 Bad Gateway** — these directives are the fix.

---

## JWT verification (`lua/jwt_verify.lua`)

1. Skips `/api/v1/health` and `/api/v1/info` (public).
2. Requires an `Authorization: Bearer <token>` header → `401` otherwise.
3. Fetches the realm public key from `KEYCLOAK_REALM_URL` once and caches the PEM for 1 hour in the `jwks_cache` shared dict (`502` if Keycloak is unreachable).
4. Verifies the RS256 signature → `401` on invalid/expired tokens.
5. Injects `X-User-Sub`, `X-User-Email`, and `X-User-Roles` (comma-joined from `realm_access.roles`) for the upstream.

All error responses use the same `ApiResponse` envelope as the backend:
`{ "status", "message", "data": null, "timestamp" }`.

---

## Upstreams (templated at startup)

`conf.d/upstreams.conf.template` is rendered by `docker-entrypoint.sh` with `envsubst` into `upstreams.conf` on container start, so upstream hosts are environment-driven:

| Env var | Default | Used for |
|---------|---------|----------|
| `SPRING_BACKEND_HOST` | `spring-boot-1:8080` | Spring Boot instance 1 |
| `SPRING_BACKEND_HOST_2` | `spring-boot-2:8080` | Spring Boot instance 2 (load-balanced) |
| `NEXTJS_FRONTEND_HOST` | `nextjs:3000` | Next.js frontend |
| `KEYCLOAK_HOST` | `keycloak:8080` | Keycloak |
| `KEYCLOAK_REALM_URL` | `http://keycloak:8080/realms/bankapp` | Lua public-key fetch (set to the `/auth/realms/bankapp` path in compose) |

`spring_backend` lists both instances, so `/api/*` traffic is round-robined across the two Spring Boot containers.

---

## Layout

```
Dockerfile                    — OpenResty + opm install of lua-resty-jwt / -http
nginx.conf                    — http{} block: resolver, rate-limit zones, JSON logs,
                                jwks_cache shared dict, includes conf.d/*.conf
docker-entrypoint.sh          — envsubst upstreams template → upstreams.conf, exec openresty
conf.d/
  bankapp.conf                — server blocks, TLS, routing, proxy buffers
  upstreams.conf.template     — upstream definitions (envsubst source)
lua/
  jwt_verify.lua              — edge JWT validation + X-User-* header injection
  logger.lua                  — structured JSON access logging
certs/
  generate-certs.sh           — makes a self-signed localhost cert pair
  localhost.crt / .key        — dev TLS cert
```

> `nginx.conf` and `conf.d/` are **copied into the image** at build time (not volume-mounted). After changing them, rebuild: `docker compose up --build -d gateway`. A live `openresty -s reload` works for a running container but is lost on `down`/`up`.

---

## Running

The gateway is started as part of the full stack from the parent `SpringBOOOO/` directory:

```bash
# one-time: generate a self-signed cert
cd certs && bash generate-certs.sh && cd ..

# from SpringBOOOO/ (where docker-compose.yml lives)
docker compose up --build -d
```

Health check: `curl -k https://localhost/gateway/health`
