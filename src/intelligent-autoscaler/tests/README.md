# Intelligent Autoscaler Test Suite

This directory will contain unit tests for the intelligent autoscaling Lambda function.

## Test Coverage

### Unit Tests (Planned)

- **MetricAnalyzer**
  - `test_get_metric_statistics()` - Verify CloudWatch metric retrieval
  - `test_calculate_trend()` - Test linear regression implementation
  - `test_filter_noise()` - Validate coefficient of variation filtering

- **ScalingDecisionEngine**
  - `test_collect_metrics()` - Ensure all metrics are collected
  - `test_make_scaling_decision()` - Validate decision logic
  - `test_signal_correlation()` - Test multi-metric requirement (≥2 signals)
  - `test_reactive_vs_proactive_mode()` - Verify trigger mode handling

### Integration Tests (Planned)

- **End-to-End Lambda Execution**
  - Test with mocked CloudWatch responses
  - Validate published metrics
  - Verify log output format

### Load Tests (Planned)

- Simulate 1000 metric data points
- Test noise filtering with random spikes
- Validate trend detection accuracy

## Running Tests

```bash
# Install dependencies
pip install -r requirements-test.txt

# Run unit tests
pytest tests/unit/

# Run with coverage
pytest --cov=lambda_function tests/
```

## Test Data

Example metric data for testing:

```python
# Stable pattern (should result in "no action")
stable_cpu = [30, 31, 29, 30, 32, 30, 29, 31, 30, 30]

# Increasing trend (should trigger scale up)
increasing_cpu = [40, 45, 50, 55, 60, 65, 70, 75, 80, 85]

# Noise pattern (should be filtered)
noisy_cpu = [50, 51, 50, 52, 50, 51, 50, 51, 50, 51]

# Spike pattern (should be filtered as transient)
spike_cpu = [30, 30, 30, 85, 30, 30, 30, 30, 30, 30]
```

## Mocking CloudWatch

Use `moto` library to mock AWS services:

```python
from moto import mock_cloudwatch
import boto3

@mock_cloudwatch
def test_metric_collection():
    # Create mock CloudWatch client
    client = boto3.client('cloudwatch', region_name='us-east-1')
    
    # Put mock metric data
    client.put_metric_data(
        Namespace='ContainerInsights',
        MetricData=[{
            'MetricName': 'pod_cpu_utilization',
            'Value': 75.0,
            'Dimensions': [
                {'Name': 'ClusterName', 'Value': 'test-cluster'},
                {'Name': 'Namespace', 'Value': 'test-ns'}
            ]
        }]
    )
    
    # Test metric retrieval
    analyzer = MetricAnalyzer('ContainerInsights', 'pod_cpu_utilization', [])
    values = analyzer.get_metric_statistics(10)
    
    assert len(values) > 0
```

## CI/CD Integration

Tests should run automatically on:
- Pull requests
- Before Terraform deployment
- Nightly builds

## Future Enhancements

- Property-based testing with Hypothesis
- Chaos testing (random metric patterns)
- Performance benchmarks (sub-second execution)
