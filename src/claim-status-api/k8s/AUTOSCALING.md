# Autoscaling Configuration

This directory contains autoscaling configurations for the claim-status-api service.

## HorizontalPodAutoscaler (HPA)

**File:** `claim-status-api-hpa.yaml`

Automatically scales the number of pods based on CPU and memory utilization:

- **Min replicas:** 2
- **Max replicas:** 10
- **Scale-up triggers:**
  - CPU utilization > 70%
  - Memory utilization > 80%
- **Scale-up behavior:** Fast (up to 4 pods or 100% increase every 30s)
- **Scale-down behavior:** Gradual (up to 2 pods or 50% decrease every 60s, with 5min stabilization)

### Verify HPA Status

```bash
kubectl get hpa claim-status-api-hpa -n materclaims
kubectl describe hpa claim-status-api-hpa -n materclaims
```

## VerticalPodAutoscaler (VPA)

**File:** `claim-status-api-vpa.yaml`

Analyzes CPU and memory usage patterns and provides resource optimization recommendations:

- **Mode:** Initial (sets resources only on new pod creation, doesn't update running pods)
- **Min resources:** 100m CPU, 256Mi memory
- **Max resources:** 2000m CPU, 2Gi memory (higher bounds for Bedrock API processing)
- **Behavior:** Continuously monitors and recommends, but only applies to newly created pods

**How it works with Initial mode:**
1. VPA observes actual CPU/memory usage of running pods
2. Generates recommendations based on historical patterns
3. Applies recommendations ONLY when new pods are created (deployment updates, scaling events, pod crashes)
4. Existing pods continue running with current resources unchanged
5. To apply latest recommendations: `kubectl rollout restart deployment claim-status-api -n materclaims`

### Prerequisites

VPA requires the Vertical Pod Autoscaler controller to be installed in your EKS cluster.

**Install VPA:**

```bash
# Clone the VPA repository
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler

# Install VPA components
./hack/vpa-up.sh
```

Or using Helm:

```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update
helm install vpa fairwinds-stable/vpa --namespace kube-system
```

### Verify VPA Status

```bash
kubectl get vpa claim-status-api-vpa -n materclaims
kubectl describe vpa claim-status-api-vpa -n materclaims
```

## Important Considerations

### HPA + VPA Coexistence

When both HPA and VPA are enabled:

1. **HPA** manages the number of pod replicas based on CPU/memory utilization
2. **VPA** manages individual pod resource requests/limits

**Current Configuration:** VPA is set to "Initial" mode to avoid conflicts with HPA.

**How they work together:**

1. **VPA (Initial mode):**
   - Monitors CPU/memory usage patterns over time
   - Generates optimal resource recommendations
   - Applies recommendations ONLY to new pods (not existing ones)
   - Does NOT restart or evict running pods

2. **HPA:**
   - Monitors current CPU/memory utilization
   - Scales pod count up/down based on thresholds
   - Operates independently without VPA interference

**Benefits of this configuration:**

✅ **No conflicts** - VPA doesn't restart pods, so HPA controls replica count without interference

✅ **Stable operations** - Running pods aren't disrupted by resource changes

✅ **Gradual optimization** - Resource improvements applied during natural pod lifecycle events

✅ **Predictable scaling** - HPA behavior is deterministic and fast

**When VPA recommendations are applied:**
- New pods created by HPA scale-up
- Pods recreated after crashes
- Manual deployment updates: `kubectl rollout restart deployment claim-status-api -n materclaims`
- Rolling updates triggered by configuration changes

**Alternative configurations (not currently used):**

1. **VPA "Auto" mode** (not recommended with HPA)
   - VPA can restart pods to apply recommendations
   - Risk of conflict: VPA increases resources → HPA scales down → thrashing
   - Only use if HPA is disabled or uses custom metrics

2. **Custom metrics for HPA**
   - Use request rate, queue depth instead of CPU/memory for HPA scaling
   - Let VPA handle CPU/memory optimization in Auto mode
   - Requires Prometheus adapter or custom metrics API

### Monitoring

```bash
# Watch autoscaling in action
watch kubectl get hpa,vpa,pods -n materclaims

# View HPA events
kubectl get events -n materclaims --field-selector involvedObject.name=claim-status-api-hpa

# View VPA recommendations
kubectl describe vpa claim-status-api-vpa -n materclaims | grep -A 20 "Recommendation"
```

## Performance Testing

Test autoscaling with the performance test pipeline stage:

```bash
# Trigger CodePipeline to run performance tests
# This will generate load and trigger HPA scaling
```

The k6 performance tests will generate load that should trigger:
1. **HPA** to scale up pods when CPU/memory > thresholds (immediate response)
2. **VPA** to learn usage patterns and update recommendations (applied to new pods created by HPA)

### Applying VPA Recommendations

To apply the latest VPA recommendations to all pods:

```bash
# Check current recommendations
kubectl describe vpa claim-status-api-vpa -n materclaims

# Apply recommendations by restarting deployment
kubectl rollout restart deployment claim-status-api -n materclaims

# Watch new pods come up with updated resources
kubectl get pods -n materclaims -l app=claim-status-api -w

# Verify new resource requests
kubectl get pods -n materclaims -l app=claim-status-api -o jsonpath='{.items[0].spec.containers[0].resources}' | jq .
```

**Best practice:** Review and apply VPA recommendations periodically (e.g., weekly) during maintenance windows or after significant traffic pattern changes.
