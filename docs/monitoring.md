# Monitoring & Health Checks

How the system knows it's healthy, and how humans find out when it isn't.

## Health surface (probes)

| Endpoint | Meaning | Consumed by | On failure |
|----------|---------|-------------|------------|
| `/health/live` | Process is up | Kubernetes liveness probe, Docker HEALTHCHECK, ALB health check | Container restarted |
| `/health/ready` | Dependencies reachable (DynamoDB ping) | Kubernetes readiness probe, CD verification | Pod removed from Service endpoints - **not** restarted |

The split is deliberate (app Issue #3, chart Issue #12): a DynamoDB outage
makes pods *not ready* (traffic stops) but never *not live* (no restart
storm that would turn a dependency incident into a compute incident).

## Log pipeline (now complete)

```
FastAPI app ── masks sensitive fields in-process (app/core/logging.py)
   └─ structured JSON on stdout
       └─ Fluent Bit DaemonSet (fluentbit module, IRSA write-only role)
           └─ CloudWatch log group /varonis-restaurant-api/dev/application
               · CMK-encrypted (logs key) · 30-day retention
               ├─ metric filter: {$.level = "ERROR"} → ApplicationErrors
               │    └─ alarm: >5 errors / 5 min → alarm state
               └─ Logs Insights (ad-hoc queries)
```

Also shipping: EKS control-plane logs (api, audit, authenticator) to
`/aws/eks/<cluster>/cluster` - the API-server audit trail.

## Querying (CloudWatch Logs Insights)

```
# Recent errors with context
fields @timestamp, message, path, status, request_id
| filter level = "ERROR" | sort @timestamp desc | limit 50

# Latency by endpoint (from the request middleware's duration_ms)
fields path, duration_ms | filter event = "http_request"
| stats avg(duration_ms), pct(duration_ms, 95) by path

# Traffic and error rate
fields status | filter event = "http_request"
| stats count() as requests, sum(status >= 500) as errors by bin(5m)
```

These work because every log line is one JSON object - the payoff of
structured logging.

## Alerting

One alarm to start: `*-app-error-spike` - more than 5 ERROR lines in 5
minutes (`treat_missing_data = notBreaching`: silence is health, not
mystery). `alarm_actions` is an empty list by default; wiring an SNS
topic + subscription is a one-variable change when a pager exists.
Deliberately minimal: alarms nobody acts on train people to ignore alarms.

## Deployment verification (cd-verify job, Issue #14)

Every delivery is verified in-cluster by an ephemeral ARC runner:
ArgoCD convergence to the exact pushed SHA → `kubectl rollout status` →
`/health/live` + `/health/ready` over Service DNS → smoke tests
(recommendation query returns the envelope; invalid input returns 422).
A deployment isn't "done" when the pipeline pushes - it's done when the
new pods answer correctly.

## Gaps acknowledged

Metrics beyond logs (Prometheus/Grafana or CloudWatch Container
Insights) and tracing are out of scope for this exercise; the log-derived
error metric plus latency fields in every request line cover the
essentials. The natural next steps are documented so they're a choice,
not an omission.
