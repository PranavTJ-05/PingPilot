# 🧭 PingPilot

> **High-Throughput Synthetic Telemetry Engine, Distributed Vantage Probing & Automated Incident Orchestration.**

PingPilot is an open-source, cloud-native synthetic monitoring and incident response platform designed for engineering teams that demand millisecond-accurate availability metrics, anti-flapping alerting heuristics, and seamless public communication.

Built from the ground up in **Go (Gin & GORM)**, **PostgreSQL 16**, **Redis 7**, and **React 19**, PingPilot unifies synthetic probing, multi-region worker pools, on-call schedules, transactional outbox notifications, and hosted public status pages into a cohesive self-hosted system.

---

## 🌟 Key Architecture & Capabilities

```mermaid
flowchart TD
    subgraph Ingress["Traffic & Operator Control"]
        Clients["DevOps & API Consumers"] -->|REST / Bearer Auth| API["PingPilot API (:8008)"]
        UI["React Operations Console"] -->|Embed / SPA| API
        StatusReq["Public Users"] -->|Custom Domain / Slug| API
    end

    subgraph State["State & Persistence"]
        API --> DB[("PostgreSQL 16 (GORM)")]
        API --> Broker[("Redis 7 Stream / Queues")]
    end

    subgraph DispatchGrid["Probe Execution Grid"]
        Scheduler["Distributed Scheduler (Leader-Elected)"] --> Broker
        Broker --> WorkerCluster["Goroutine Worker Pools (cmd/worker)"]
        WorkerCluster --> NetworkProbes["TCP / UDP / DNS / TLS Probes"]
        WorkerCluster --> HTTPProbes["HTTP / API Assertions / Trace"]
        WorkerCluster --> CronProbes["Cron Heartbeat Verification"]
        WorkerCluster -.->|Job Dispatch| BrowserSidecar["Playwright Synthetic Sidecar"]
        Agents["Remote Private Agents"] -->|Poll / Jobs| API
    end

    subgraph AlertPipeline["Reliability & Notification Engine"]
        WorkerCluster --> RulesEngine["Alert Suppression & Incident Engine"]
        RulesEngine --> Outbox[("Transactional Outbox")]
        Outbox --> DeliveryAgent["Notification Dispatcher"]
        DeliveryAgent --> Channels["Slack · Twilio SMS · Expo Push · Webhooks"]
    end
```

---

## 🚀 Feature Highlights

### 1. Comprehensive Synthetic Probing
* **HTTP / HTTPS Tracing**: Millisecond resolution with `net/http/httptrace` dissecting DNS lookup, TCP dial, TLS handshake, and Time-to-First-Byte (TTFB).
* **Deep API Validation**: JSONPath assertions (`$.status == "ok"`), status code bounds, custom headers, and tokenized payloads.
* **Network Protocol Probes**: Raw TCP connect socket dials, UDP echo packets, DNS resolver queries (A, AAAA, CNAME, TXT, MX), and ICMP/TCP ping.
* **TLS Certificate Expiry Audits**: Automatic certificate expiration warnings with configurable degradation thresholds.
* **Domain Lifecycle via RDAP**: Live domain registration tracking to prevent inadvertent expirations.
* **Cron & Heartbeat Monitoring**: Inverted push probes for background workers and cron jobs. Automatically opens incidents if expected check-ins miss their deadlines.
* **Multi-Step Synthetic Journeys**: Scripted chained HTTP requests that extract dynamic session tokens or variables from intermediate responses.
* **Browser Automation (Playwright)**: Full browser headless synthetic workflows capturing failure screenshots, console traces, and network waterfall logs.

### 2. Intelligent Alert Suppression (Anti-Fatigue)
* **Consecutive Failure Thresholds**: Filter out transient network blips by requiring $K$ confirmed failures before tripping an alert.
* **Regional Quorum Consensus**: Probe from multiple vantage points; incidents only fire when a minimum quorum of distinct regions agree on downtime.
* **Dependency Tree Suppression**: If a parent infrastructure component (e.g., ingress gateway or load balancer) fails, all dependent microservice alerts are gracefully suppressed to eliminate alarm storms.
* **Flapping Cooldown & Hysteresis**: Detects unstable flapping monitors and suppresses notification floods during recovery oscillation.
* **Recurring Maintenance Windows**: Full RFC-5545 RRULE recurring maintenance window scheduling.

### 3. Incident Lifecycle & Collaboration
* **Full Incident State Machine**: `open` $\rightarrow$ `acknowledged` $\rightarrow$ `investigating` $\rightarrow$ `identified` $\rightarrow$ `monitoring` $\rightarrow$ `resolved`.
* **Audited Timeline**: Every probe verdict, note, assignee change, and escalation decision is recorded into an append-only timeline.
* **Automated Post-Mortems**: Generate structured post-mortem summaries and export them to Markdown in one click.
* **Action Items**: Track preventive remediation items with designated assignees and due dates.

### 4. Enterprise Multi-Channel Notifications
* **Transactional Outbox Architecture**: Notifications are queued inside the same database transaction as the incident state change, guaranteeing zero alert loss during service restarts.
* **Rich Notification Providers**:
  - HMAC-SHA256 Signed Webhooks (`X-PingPilot-Signature`)
  - Slack Incoming Webhooks & Block Kit messages
  - Expo Push Notifications for iOS and Android
  - Twilio SMS and Voice alerts
  - AWS SNS SMS Delivery
  - SMTP / Email alerts with customizable templates

### 5. Multi-Tenant Organization Isolation & RBAC
* **Clerk JWT & Organization Integration**: Seamless user authentication with role mapping (`owner`, `admin`, `member`, `viewer`).
* **Hashed API Keys**: High-speed machine access with SHA-256 hashed keys.
* **Scoped Database Tenancy**: Strict database query scoping (`tenantScope`) ensures complete data isolation across organizations.

### 6. Public Status Pages & Communication
* **Custom Domains & Hosted Slugs**: Host status dashboards on custom domains or native `/s/:slug` routes.
* **Component Grouping**: Aggregate individual synthetic checks into high-level system components.
* **Double Opt-In Subscriptions**: Allow public users to subscribe for incident updates with one-click tokenized unsubscribe protection.

---

## 🛠️ Tech Stack

* **Language**: Go 1.25+
* **HTTP Engine**: Gin Web Framework
* **Persistence**: PostgreSQL 16 via GORM (with connection pooling)
* **Broker & Caching**: Redis 7
* **Frontend**: React 19, Vite, Lucide Icons (embedded into Go binary via `//go:embed`)
* **Browser Synthetics**: Node.js & Playwright container sidecar
* **Metrics**: Native Prometheus scrapers and Grafana dashboards

---

## ⚡ Quickstart (Docker Compose)

The fastest way to experience PingPilot is using the official multi-container stack:

```bash
# Clone the repository
git clone https://github.com/PranavTJ-05/PingPilot.git
cd PingPilot

# Spin up the complete fleet (API, Worker, Postgres, Redis)
make docker-up
```

* **Operations Console**: `http://localhost:8008/app`
* **API Health Check**: `http://localhost:8008/health`
* **Worker Fleet Telemetry**: `http://localhost:8008/workers`
* **Metrics Endpoint**: `http://localhost:8008/metrics`

To include the optional Prometheus and Grafana observability stack:

```bash
make metrics-up
```
* **Grafana**: `http://localhost:3000` *(Default: `admin` / `admin`)*
* **Prometheus**: `http://localhost:9090`

---

## ⚙️ Configuration Reference

PingPilot is configured via environment variables with strict validation for production environments:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `APP_ENV` | `development` | Runtime mode (`development` or `production`). Production enforces strict API keys and blocks private network targets. |
| `APP_PORT` | `8008` | HTTP API and console listening port. |
| `METRICS_PORT` | `8009` | Standalone Prometheus metrics port for worker telemetry. |
| `DATABASE_URL` | `postgres://pingpilot:pingpilot@localhost:5432/pingpilot?sslmode=disable` | PostgreSQL connection DSN. |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis instance URL. |
| `PINGPILOT_BOOTSTRAP_API_KEY` | `dev_admin_key_change_me` | Bootstrap root administrator key (minimum 16 characters in production). |
| `ALLOW_PRIVATE_TARGETS` | `false` | Enable or disable SSRF protection for local RFC-1918 / loopback addresses. |
| `CHECK_WORKER_COUNT` | `10` | Concurrency size of the worker goroutine pool. |
| `DEFAULT_CHECK_TIMEOUT_SECONDS` | `10` | Timeout threshold for network and HTTP probes. |
| `SCHEDULER_TICK_SECONDS` | `5` | Frequency of monitor polling in the scheduler loop. |
| `LOG_LEVEL` | `info` | Logging verbosity (`debug`, `info`, `warn`, `error`). |
| `WEBHOOK_SIGNING_SECRET` | _empty_ | Secret used to sign outgoing webhook payloads with HMAC-SHA256. |

---

## 📡 API Reference & Usage

### 1. Engine Health Check
```bash
curl http://localhost:8008/health
```
```json
{
  "engine": "PingPilot",
  "status": "ok",
  "version": "dev",
  "database": "ok",
  "redis": "ok",
  "time": "2026-11-04T12:00:00Z"
}
```

### 2. Live System Diagnostics
```bash
curl -H "Authorization: Bearer dev_admin_key_change_me" \
  http://localhost:8008/api/v1/system/diagnostics
```

### 3. Create an HTTP Monitor
```bash
curl -X POST http://localhost:8008/api/v1/monitors \
  -H "Authorization: Bearer dev_admin_key_change_me" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Payment Gateway",
    "type": "http",
    "target": "https://api.example.com/health",
    "method": "GET",
    "expectedStatus": 200,
    "timeoutSeconds": 5,
    "intervalSeconds": 30,
    "failureThreshold": 2,
    "enabled": true
  }'
```

### 4. Trigger an On-Demand Probe Check
```bash
curl -X POST http://localhost:8008/api/v1/monitors/<MONITOR_ID>/check-now \
  -H "Authorization: Bearer dev_admin_key_change_me"
```

---

## 🧪 Testing & Code Quality

PingPilot includes an exhaustive test suite covering checker timeouts, DNS resolution edge-cases, SSRF blocking, TLS expiration calculation, flapping detection heuristics, and on-call rotation algorithms:

```bash
make test
```

For frontend build and vet linting:
```bash
make check
```

---

## 📄 License

PingPilot is released under the MIT License. Developed and maintained by [PranavTJ-05](https://github.com/PranavTJ-05).
