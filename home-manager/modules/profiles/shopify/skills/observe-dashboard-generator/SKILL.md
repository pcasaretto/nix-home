---
name: observe-dashboard-generator
description: Generate Observe dashboards from StatsD metrics in the codebase. Use when creating dashboards for new metrics, visualizing counters/distributions, or when the user mentions "dashboard", "observe", "metrics visualization", or "observability dashboard".
---

# Observe Dashboard Generator

Generate Observe dashboard JSON files from StatsD metrics in the codebase.

## Process

### Step 1: Read the Example Dashboard

**ALWAYS start by reading `EXAMPLE_DASHBOARD.json` in this skill's directory.** This provides the canonical structure, panel configurations, and styling conventions to follow.

### Step 2: Gather Requirements

Understand what the user wants to observe:

1. **What are the goals?** Examples:
   - Validate correctness (e.g., comparing two systems)
   - Monitor replication lag / freshness
   - Track throughput and error rates
   - Track feature rollout progress

2. **Datasource UID**: Use `metrics_mainorg` (this is the standard datasource)

### Step 3: Identify the Metrics

Find where metrics are emitted:

```bash
git show --stat HEAD  # or specific commit
```

Read the source file(s) and catalog all StatsD calls:

**Counters** (`StatsD.increment`):
- Metric name, tags, what it represents

**Distributions** (`StatsD.distribution`):
- Metric name, unit (ms, bytes, count), what it measures

**Note the metric prefix** - this helps group related metrics.

### Step 4: Design Dashboard Structure Based on Goals

Map user goals to panel types:

| Goal | Panel Design |
|------|--------------|
| **Correctness/Match Rate** | Gauge showing percentage + time series with threshold line at target (e.g., 99%) |
| **Replication Lag/Freshness** | Time series with percentiles (p50, p90, p99) + threshold areas for SLO |
| **Throughput** | Stat panel for current rate + time series for trend |
| **Error Breakdown** | Stacked time series by error type/reason with distinct colors |
| **Comparison (A vs B)** | Side-by-side panels or overlaid series with clear color coding |
| **Rollout Progress** | Percentage gauge + volume comparison (old vs new path) |

**Organize into logical rows:**
- **Overview**: At-a-glance stats (gauges, single stats)
- **Core Metrics**: Main functionality panels based on primary goals
- **Operational Health**: Errors, skips, retries - things that indicate problems

### Step 5: Generate the Dashboard

**Metric name conversion** (StatsD to Prometheus):
- Dots become underscores: `app.metric.name` → `app_metric_name`

**Common query patterns:**

```promql
# Counter rate (requests per minute)
sum(rate(metric_name[$__rate_interval])) * 60

# Counter rate by tag
sum by (tag_name)(rate(metric_name[$__rate_interval])) * 60

# Success/match rate (percentage)
sum(rate(success[$__rate_interval])) /
(sum(rate(success[$__rate_interval])) + sum(rate(failure[$__rate_interval])))

# Distribution percentiles
histogram_quantile(0.50, sum(rate(metric_name[$__rate_interval])) by (le))
histogram_quantile(0.90, sum(rate(metric_name[$__rate_interval])) by (le))
histogram_quantile(0.99, sum(rate(metric_name[$__rate_interval])) by (le))
```

**Threshold guidance:**
- Success rates: red < 95%, yellow 95-99%, green > 99%
- Latency: depends on context, ask user or use sensible defaults
- Errors: typically no threshold, just track volume

**Template Variables (for dynamic filtering):**

Consider adding template variables when:
- A metric has a label with **multiple distinct values** (e.g., `verifier_type`, `region`, `action_type`)
- Users will want to **drill down** into specific values or **compare** across values
- You're creating **separate panels for each label value** - this is a sign you should use a variable instead
- The dashboard would benefit from **"All" vs "specific" views**

Don't use variables when:
- There are only 2-3 fixed values that are always relevant together
- The label values represent fundamentally different things that need different visualizations
- Overview dashboards where you always want to see everything

When you spot 3+ hardcoded panels that differ only by a label filter (e.g., `type="foo"`, `type="bar"`, `type="baz"`), consolidate them into one panel with a variable.

The `promql-query-builder` datasource requires a specific query format:

```json
"templating": {
  "list": [
    {
      "allValue": ".*",
      "current": {
        "text": ["All"],
        "value": ["$__all"]
      },
      "datasource": {
        "type": "promql-query-builder",
        "uid": "metrics_mainorg"
      },
      "definition": "label_values(your_metric_name, label_name)",
      "includeAll": true,
      "label": "Display Label",
      "multi": true,
      "name": "variable_name",
      "options": [],
      "query": {
        "advanced_query": "",
        "label": "label_name",
        "metric": "your_metric_name",
        "metricLabels": [],
        "mode": "builder",
        "qryType": 1,
        "query": "label_values(your_metric_name, label_name)",
        "refId": "PrometheusVariableQueryEditor-VariableQuery"
      },
      "refresh": 2,
      "regex": "",
      "sort": 1,
      "type": "query"
    }
  ]
}
```

**Critical:** The `query` object must include `mode: "builder"`, `metric`, and `label` fields - a plain `label_values()` string won't work with `promql-query-builder`.

Then use the variable in queries with regex matching:
```promql
sum by (tag)(rate(metric{label_name=~"$variable_name"}[$__rate_interval]))
```

### Step 6: Write and Validate

Save to an appropriate location (ask if unclear):
- Component's `dashboards/` directory if it exists
- Or wherever user specifies

## Examples

See [EXAMPLE_DASHBOARD.json](EXAMPLE_DASHBOARD.json) for a complete dashboard that monitors:
- Event correctness (match rate gauge + time series)
- Replication lag (percentile distributions)
- Operational health (skips by reason, errors by type)
- Message outcome distribution (stacked percentage view)

See [EXAMPLE_DASHBOARD_WITH_VARIABLES.json](EXAMPLE_DASHBOARD_WITH_VARIABLES.json) for a dashboard using template variables:
- Dynamic `verifier_type` dropdown populated from metric labels
- Panels that filter by selected variable value(s)
- Consolidated detail panels instead of one-per-type

## Defaults

- **Datasource UID**: `metrics_mainorg`
- **Style reference**: Always use `EXAMPLE_DASHBOARD.json` in this skill's directory

## Key Questions to Ask

If the user hasn't provided context, ask:

1. "What do you want to observe with this dashboard?" (goals)
2. "Where are the metrics defined?" (files/commits to examine)
