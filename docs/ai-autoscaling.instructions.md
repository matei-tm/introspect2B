Intelligent Scaling Controller – Key Features
The system implements an adaptive, context‑aware scaling strategy designed specifically for AI‑assisted claims‑processing workloads running on Amazon EKS. Because these workloads rely heavily on Bedrock model inference — which is comparatively slow and variable — the scaler evaluates multiple signals before taking action.
Core Capabilities
1. Context‑Aware Scaling
The controller understands the behaviour of AI workloads, especially the variable latency of Bedrock model invocations.
It factors this into scaling heuristics to avoid premature or unnecessary node/pod scaling.
2. Multi‑Metric Evaluation
Instead of relying on a single metric, the system correlates several signals:

CPU utilisation
Memory usage
API latency (including Bedrock inference duration)
Lambda invocation rates (if asynchronous claim enrichment functions are part of the workflow)

This provides a more complete, reliable picture of true system load.
3. Trend‑Based Forecasting
A rolling trend analysis model detects whether demand is increasing, stable, or decreasing.
This supports proactive scaling decisions rather than waiting for thresholds to be exceeded.
4. Intelligent Noise Filtering
Short‑lived spikes — such as transient memory increases caused by model loading or caching — are automatically filtered out.
This reduces false positives and prevents unnecessary scaling actions.
5. Explainable Decision Engine
Every scaling action includes:

The underlying metrics
The inferred reasoning
The decision path (e.g. “trend‑driven scale‑out due to sustained API latency rise”)

This makes scaling behaviour auditable and easier to tune.
6. Dual Trigger Model
The controller reacts to both real‑time changes and forecasted demand:

Reactive mode: Immediate action when alarms or hard thresholds fire.
Proactive mode: Evaluation of combined trends every 5 minutes, enabling early scaling to prevent bottlenecks.