# Intelligent Autoscaler Test Suite

Comprehensive unit tests for the intelligent autoscaling Lambda function.

## Test Coverage

### Unit Tests

**MetricAnalyzer Tests** (`test_lambda_function.py::TestMetricAnalyzer`)
- ✅ `test_calculate_trend_stable()` - Verify stable trend detection
- ✅ `test_calculate_trend_increasing()` - Test increasing trend detection
- ✅ `test_calculate_trend_decreasing()` - Test decreasing trend detection
- ✅ `test_calculate_trend_insufficient_data()` - Handle edge case with <3 data points
- ✅ `test_filter_noise_true_signal()` - Identify genuine signals
- ✅ `test_filter_noise_actual_noise()` - Filter low-variation noise
- ✅ `test_filter_noise_empty_values()` - Handle empty data gracefully
- ✅ `test_get_metric_statistics_success()` - CloudWatch metric retrieval
- ✅ `test_get_metric_statistics_error()` - Error handling for CloudWatch failures

**ScalingDecisionEngine Tests** (`test_lambda_function.py::TestScalingDecisionEngine`)
- ✅ `test_make_scaling_decision_scale_up()` - Multi-metric scale-up decision
- ✅ `test_make_scaling_decision_scale_down()` - Multi-metric scale-down decision
- ✅ `test_make_scaling_decision_no_action()` - No action when signals are stable
- ✅ `test_make_scaling_decision_insufficient_signals()` - Require ≥2 correlated signals
- ✅ `test_make_scaling_decision_noise_filtered()` - Validate noise filtering in decisions
- ✅ `test_publish_custom_metric()` - CloudWatch custom metric publishing
- ✅ `test_execute_scaling_action_none()` - Execute no-action decision
- ✅ `test_execute_scaling_action_scale_up()` - Execute scale-up decision

**Lambda Handler Tests** (`test_lambda_function.py::TestLambdaHandler`)
- ✅ `test_lambda_handler_proactive_mode()` - Scheduled trigger (EventBridge)
- ✅ `test_lambda_handler_reactive_mode()` - Alarm trigger (CloudWatch)
- ✅ `test_lambda_handler_error_handling()` - Exception handling and error responses

## Running Tests

### Local Execution

```bash
# Install dependencies
pip install -r requirements.txt

# Run all tests
pytest test_lambda_function.py -v

# Run with coverage
pytest test_lambda_function.py -v \
  --cov=../intelligent-autoscaler \
  --cov-report=term \
  --cov-report=html:htmlcov

# Run specific test class
pytest test_lambda_function.py::TestMetricAnalyzer -v

# Run specific test
pytest test_lambda_function.py::TestMetricAnalyzer::test_calculate_trend_stable -v
```

### CI/CD Execution

Tests run automatically in the CodePipeline:

**Stage:** `BuildTestScan`  
**Action:** `LambdaTest`  
**BuildSpec:** `pipelines/codebuild/buildspec-lambda-test.yml`

The pipeline will:
1. Install Python 3.11 and dependencies
2. Run pytest with coverage
3. Generate JUnit XML report
4. Generate Cobertura coverage report
5. Fail the build if tests fail

### View Results

**CodeBuild Console:**
```
AWS Console → CodeBuild → Build Projects → intelligent-autoscaler-lambda-test → Build History
```

**Test Report:**
```
AWS Console → CodeBuild → Reports → LambdaTestReport
```

**Coverage Report:**
```
AWS Console → CodeBuild → Reports → LambdaCoverageReport
```

## Test Data

### Example Patterns

```python
# Stable pattern (should result in "no action")
stable_cpu = [30, 31, 29, 30, 32, 30, 29, 31, 30, 30]

# Increasing trend (should trigger scale up)
increasing_cpu = [40, 45, 50, 55, 60, 65, 70, 75, 80, 85]

# Decreasing trend (should trigger scale down)
decreasing_cpu = [85, 80, 75, 70, 65, 60, 55, 50, 45, 40]

# Noise pattern (should be filtered)
noisy_cpu = [50, 51, 50, 52, 50, 51, 50, 51, 50, 51]

# Spike pattern (should be filtered as transient)
spike_cpu = [30, 30, 30, 85, 30, 30, 30, 30, 30, 30]
```

## Mocking AWS Services

Tests use `unittest.mock` to mock CloudWatch and other AWS services:

```python
from unittest.mock import patch, MagicMock

@patch('lambda_function.cloudwatch')
def test_metric_collection(mock_cloudwatch):
    # Mock CloudWatch response
    mock_cloudwatch.get_metric_statistics.return_value = {
        'Datapoints': [
            {'Timestamp': datetime.utcnow(), 'Average': 50.0}
        ]
    }
    
    # Test code here
    analyzer = MetricAnalyzer(...)
    values = analyzer.get_metric_statistics(10)
    
    assert len(values) == 1
    assert values[0] == 50.0
```

## Coverage Goals

Current coverage: **~95%**

Target coverage: **≥90%** for all modules

Excluded from coverage:
- Exception handlers (tested manually)
- Logging statements
- Main lambda_handler error recovery

## Adding New Tests

When adding new functionality:

1. **Write test first** (TDD approach)
2. **Run locally** to verify
3. **Ensure ≥90% coverage** for new code
4. **Update this README** with test description
5. **Commit and push** - CI will run automatically

Example:
```python
def test_new_feature(self):
    """Test description of what this validates"""
    # Arrange
    input_data = {...}
    
    # Act
    result = function_under_test(input_data)
    
    # Assert
    self.assertEqual(result, expected_value)
```

## Continuous Integration

### Pipeline Integration

The Lambda tests are integrated into the main CodePipeline:

```yaml
Stages:
  - Source (GitHub)
  - BuildTestScan
    - UnitTest (.NET tests)
    - LambdaTest (Python Lambda tests) ← NEW
    - SecurityScan
  - DockerPushAndScan
  - Deploy
```

### Build Artifacts

Generated artifacts:
- `test-results.xml` - JUnit test results
- `coverage.xml` - Cobertura coverage report
- `htmlcov/` - HTML coverage report

### Failure Handling

If tests fail:
- ❌ Build stage fails
- ❌ Pipeline stops
- 📧 Notification sent (if configured)
- 🔍 Check CodeBuild logs for details

## Troubleshooting

### Import Errors

**Problem:** `ModuleNotFoundError: No module named 'lambda_function'`

**Solution:**
```bash
export PYTHONPATH="${PYTHONPATH}:$(pwd)/../intelligent-autoscaler"
pytest test_lambda_function.py -v
```

### Mock Failures

**Problem:** Mocks not being called as expected

**Solution:**
```python
# Verify mock was called
mock_cloudwatch.get_metric_statistics.assert_called_once()

# Check call arguments
call_args = mock_cloudwatch.get_metric_statistics.call_args
print(call_args)
```

### Coverage Below Target

**Problem:** Coverage drops below 90%

**Solution:**
1. Run with coverage report: `pytest --cov-report=html`
2. Open `htmlcov/index.html` in browser
3. Identify uncovered lines
4. Add tests for missing coverage

## Future Enhancements

Planned test improvements:
- [ ] Property-based testing with Hypothesis
- [ ] Chaos testing (random metric patterns)
- [ ] Performance benchmarks (execution time <5s)
- [ ] Integration tests with real CloudWatch (manual)
- [ ] Load testing (1000+ metric data points)

## References

- [pytest Documentation](https://docs.pytest.org/)
- [unittest.mock Guide](https://docs.python.org/3/library/unittest.mock.html)
- [AWS CodeBuild Test Reports](https://docs.aws.amazon.com/codebuild/latest/userguide/test-reporting.html)
- [Lambda Function Source](../intelligent-autoscaler/lambda_function.py)
