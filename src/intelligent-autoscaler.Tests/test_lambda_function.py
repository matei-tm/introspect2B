"""
Unit tests for the Intelligent Autoscaler Lambda function
"""
import unittest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'intelligent-autoscaler'))

from lambda_function import MetricAnalyzer, ScalingDecisionEngine


class TestMetricAnalyzer(unittest.TestCase):
    """Test cases for MetricAnalyzer class"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.analyzer = MetricAnalyzer(
            namespace='TestNamespace',
            metric_name='TestMetric',
            dimensions=[{'Name': 'Test', 'Value': 'Value'}]
        )
    
    def test_calculate_trend_stable(self):
        """Test trend calculation for stable pattern"""
        values = [30, 31, 29, 30, 32, 30, 29, 31, 30, 30]
        trend_direction, trend_magnitude = self.analyzer.calculate_trend(values)
        
        self.assertEqual(trend_direction, 'stable')
        self.assertLess(trend_magnitude, 0.15)  # Below trend threshold
    
    def test_calculate_trend_increasing(self):
        """Test trend calculation for increasing pattern"""
        values = [20, 30, 40, 50, 60, 70, 80, 90, 100, 110]
        trend_direction, trend_magnitude = self.analyzer.calculate_trend(values)
        
        self.assertEqual(trend_direction, 'increasing')
        self.assertGreater(trend_magnitude, 0.15)  # Above trend threshold
    
    def test_calculate_trend_decreasing(self):
        """Test trend calculation for decreasing pattern"""
        values = [110, 100, 90, 80, 70, 60, 50, 40, 30, 20]
        trend_direction, trend_magnitude = self.analyzer.calculate_trend(values)
        
        self.assertEqual(trend_direction, 'decreasing')
        self.assertGreater(trend_magnitude, 0.15)
    
    def test_calculate_trend_insufficient_data(self):
        """Test trend calculation with insufficient data points"""
        values = [30, 31]
        trend_direction, trend_magnitude = self.analyzer.calculate_trend(values)
        
        self.assertEqual(trend_direction, 'stable')
        self.assertEqual(trend_magnitude, 0.0)
    
    def test_filter_noise_true_signal(self):
        """Test noise filter identifies true signal"""
        # High variation = signal
        values = [30, 40, 50, 60, 70, 80]
        is_signal = self.analyzer.filter_noise(values)
        
        self.assertTrue(is_signal)
    
    def test_filter_noise_actual_noise(self):
        """Test noise filter identifies noise"""
        # Low variation = noise
        values = [50, 51, 50, 52, 50, 51, 50, 51, 50, 51]
        is_signal = self.analyzer.filter_noise(values)
        
        self.assertFalse(is_signal)
    
    def test_filter_noise_empty_values(self):
        """Test noise filter with empty values"""
        values = []
        is_signal = self.analyzer.filter_noise(values)
        
        self.assertFalse(is_signal)
    
    @patch('lambda_function.cloudwatch')
    def test_get_metric_statistics_success(self, mock_cloudwatch):
        """Test successful metric retrieval from CloudWatch"""
        # Mock CloudWatch response
        mock_cloudwatch.get_metric_statistics.return_value = {
            'Datapoints': [
                {'Timestamp': datetime.utcnow(), 'Average': 50.0},
                {'Timestamp': datetime.utcnow() + timedelta(minutes=1), 'Average': 55.0},
                {'Timestamp': datetime.utcnow() + timedelta(minutes=2), 'Average': 60.0}
            ]
        }
        
        values = self.analyzer.get_metric_statistics(10, 'Average')
        
        self.assertEqual(len(values), 3)
        self.assertEqual(values[0], 50.0)
        self.assertEqual(values[1], 55.0)
        self.assertEqual(values[2], 60.0)
    
    @patch('lambda_function.cloudwatch')
    def test_get_metric_statistics_error(self, mock_cloudwatch):
        """Test metric retrieval handles errors gracefully"""
        mock_cloudwatch.get_metric_statistics.side_effect = Exception("CloudWatch error")
        
        values = self.analyzer.get_metric_statistics(10)
        
        self.assertEqual(values, [])


class TestScalingDecisionEngine(unittest.TestCase):
    """Test cases for ScalingDecisionEngine class"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.engine = ScalingDecisionEngine(
            cluster_name='test-cluster',
            namespace='test-namespace',
            deployment='test-deployment'
        )
    
    def test_make_scaling_decision_scale_up(self):
        """Test scaling decision with clear scale-up signals"""
        metrics = {
            'cpu': {
                'values': [60, 65, 70, 75, 80],
                'current': 80,
                'trend': ('increasing', 0.20),
                'is_signal': True
            },
            'memory': {
                'values': [70, 75, 80, 85, 90],
                'current': 90,
                'trend': ('increasing', 0.18),
                'is_signal': True
            },
            'latency': {
                'values': [3000, 3500, 4000, 4500, 5000],
                'current': 5000,
                'trend': ('increasing', 0.22),
                'is_signal': True
            },
            'bedrock': {
                'values': [2500, 2700, 2900, 3100, 3300],
                'current': 3300,
                'trend': ('increasing', 0.15),
                'is_signal': True
            }
        }
        
        decision = self.engine.make_scaling_decision(metrics)
        
        self.assertEqual(decision['action'], 'scale_up')
        self.assertIn('Multi-metric evaluation:', decision['reason'][0])
        self.assertGreaterEqual(decision['reason'][0].count('scale-up'), 1)
    
    def test_make_scaling_decision_scale_down(self):
        """Test scaling decision with clear scale-down signals"""
        metrics = {
            'cpu': {
                'values': [50, 45, 40, 35, 30],
                'current': 25,
                'trend': ('decreasing', 0.20),
                'is_signal': True
            },
            'memory': {
                'values': [60, 55, 50, 45, 40],
                'current': 35,
                'trend': ('decreasing', 0.18),
                'is_signal': True
            },
            'latency': {
                'values': [3000, 2800, 2600, 2400, 2200],
                'current': 2200,
                'trend': ('decreasing', 0.15),
                'is_signal': True
            },
            'bedrock': {
                'values': [2500, 2400, 2300, 2200, 2100],
                'current': 2100,
                'trend': ('decreasing', 0.10),
                'is_signal': True
            }
        }
        
        decision = self.engine.make_scaling_decision(metrics)
        
        self.assertEqual(decision['action'], 'scale_down')
        self.assertIn('Multi-metric evaluation:', decision['reason'][0])
    
    def test_make_scaling_decision_no_action(self):
        """Test scaling decision with no clear signals"""
        metrics = {
            'cpu': {
                'values': [50, 50, 50, 50, 50],
                'current': 50,
                'trend': ('stable', 0.01),
                'is_signal': False
            },
            'memory': {
                'values': [45, 45, 45, 45, 45],
                'current': 45,
                'trend': ('stable', 0.01),
                'is_signal': False
            },
            'latency': {
                'values': [2000, 2000, 2000, 2000, 2000],
                'current': 2000,
                'trend': ('stable', 0.01),
                'is_signal': False
            },
            'bedrock': {
                'values': [1500, 1500, 1500, 1500, 1500],
                'current': 1500,
                'trend': ('stable', 0.01),
                'is_signal': False
            }
        }
        
        decision = self.engine.make_scaling_decision(metrics)
        
        self.assertEqual(decision['action'], 'none')
        self.assertIn('No correlated signals', decision['reason'][0])
    
    def test_make_scaling_decision_insufficient_signals(self):
        """Test scaling decision with only one signal (should not scale)"""
        metrics = {
            'cpu': {
                'values': [60, 65, 70, 75, 80],
                'current': 80,
                'trend': ('increasing', 0.20),
                'is_signal': True
            },
            'memory': {
                'values': [45, 45, 45, 45, 45],
                'current': 45,
                'trend': ('stable', 0.01),
                'is_signal': False
            },
            'latency': {
                'values': [2000, 2000, 2000, 2000, 2000],
                'current': 2000,
                'trend': ('stable', 0.01),
                'is_signal': False
            },
            'bedrock': {
                'values': [1500, 1500, 1500, 1500, 1500],
                'current': 1500,
                'trend': ('stable', 0.01),
                'is_signal': False
            }
        }
        
        decision = self.engine.make_scaling_decision(metrics)
        
        # Should not scale with only 1 signal
        self.assertEqual(decision['action'], 'none')
    
    def test_make_scaling_decision_noise_filtered(self):
        """Test that noise is properly filtered from decision"""
        metrics = {
            'cpu': {
                'values': [50, 51, 50, 52, 50],
                'current': 50,
                'trend': ('stable', 0.02),
                'is_signal': False  # Filtered as noise
            },
            'memory': {
                'values': [45, 46, 45, 47, 45],
                'current': 45,
                'trend': ('stable', 0.02),
                'is_signal': False  # Filtered as noise
            },
            'latency': {
                'values': [2000, 2050, 2000, 2100, 2000],
                'current': 2000,
                'trend': ('stable', 0.03),
                'is_signal': False  # Filtered as noise
            },
            'bedrock': {
                'values': [1500, 1550, 1500, 1600, 1500],
                'current': 1500,
                'trend': ('stable', 0.04),
                'is_signal': False  # Filtered as noise
            }
        }
        
        decision = self.engine.make_scaling_decision(metrics)
        
        self.assertEqual(decision['action'], 'none')
        # Check that reason mentions noise filtering
        noise_mentions = sum(1 for r in decision['reason'] if 'noise' in r.lower())
        self.assertGreater(noise_mentions, 0)
    
    @patch('lambda_function.cloudwatch')
    def test_publish_custom_metric(self, mock_cloudwatch):
        """Test custom metric publishing to CloudWatch"""
        self.engine.publish_custom_metric('TestMetric', 1.0, 'Count')
        
        mock_cloudwatch.put_metric_data.assert_called_once()
        call_args = mock_cloudwatch.put_metric_data.call_args
        
        self.assertEqual(call_args[1]['Namespace'], 'IntelligentAutoscaler')
        self.assertEqual(call_args[1]['MetricData'][0]['MetricName'], 'TestMetric')
        self.assertEqual(call_args[1]['MetricData'][0]['Value'], 1.0)
    
    @patch('lambda_function.cloudwatch')
    def test_execute_scaling_action_none(self, mock_cloudwatch):
        """Test execution of no-action decision"""
        decision = {
            'action': 'none',
            'reason': ['No signals detected'],
            'metrics_evaluated': {}
        }
        
        result = self.engine.execute_scaling_action(decision)
        
        self.assertTrue(result)
        # Should publish 0 for no action
        mock_cloudwatch.put_metric_data.assert_called()
    
    @patch('lambda_function.cloudwatch')
    def test_execute_scaling_action_scale_up(self, mock_cloudwatch):
        """Test execution of scale-up decision"""
        decision = {
            'action': 'scale_up',
            'mode': 'proactive',
            'reason': ['High CPU usage'],
            'metrics_evaluated': {},
            'timestamp': datetime.utcnow().isoformat()
        }
        
        result = self.engine.execute_scaling_action(decision)
        
        self.assertTrue(result)
        # Should publish 1 for scale up
        mock_cloudwatch.put_metric_data.assert_called()


class TestLambdaHandler(unittest.TestCase):
    """Test cases for Lambda handler function"""
    
    @patch.dict(os.environ, {
        'EKS_CLUSTER_NAME': 'test-cluster',
        'NAMESPACE': 'test-namespace',
        'DEPLOYMENT_NAME': 'test-deployment',
        'MIN_REPLICAS': '2',
        'MAX_REPLICAS': '10',
        'METRIC_WINDOW_MINUTES': '10',
        'TREND_THRESHOLD': '0.15',
        'NOISE_FILTER_THRESHOLD': '0.05'
    })
    @patch('lambda_function.ScalingDecisionEngine')
    def test_lambda_handler_proactive_mode(self, mock_engine_class):
        """Test Lambda handler in proactive mode"""
        from lambda_function import lambda_handler
        
        # Mock the engine
        mock_engine = MagicMock()
        mock_engine_class.return_value = mock_engine
        mock_engine.collect_metrics.return_value = {}
        mock_engine.make_scaling_decision.return_value = {
            'action': 'none',
            'reason': ['Test'],
            'mode': 'proactive'
        }
        mock_engine.execute_scaling_action.return_value = True
        
        # Proactive trigger (scheduled)
        event = {'source': 'aws.events'}
        context = {}
        
        response = lambda_handler(event, context)
        
        self.assertEqual(response['statusCode'], 200)
        mock_engine.collect_metrics.assert_called_once()
        mock_engine.make_scaling_decision.assert_called_once()
    
    @patch.dict(os.environ, {
        'EKS_CLUSTER_NAME': 'test-cluster',
        'NAMESPACE': 'test-namespace',
        'DEPLOYMENT_NAME': 'test-deployment'
    })
    @patch('lambda_function.ScalingDecisionEngine')
    def test_lambda_handler_reactive_mode(self, mock_engine_class):
        """Test Lambda handler in reactive mode"""
        from lambda_function import lambda_handler
        
        # Mock the engine
        mock_engine = MagicMock()
        mock_engine_class.return_value = mock_engine
        mock_engine.collect_metrics.return_value = {}
        mock_engine.make_scaling_decision.return_value = {
            'action': 'scale_up',
            'reason': ['Alarm triggered'],
            'mode': 'reactive'
        }
        mock_engine.execute_scaling_action.return_value = True
        
        # Reactive trigger (CloudWatch alarm)
        event = {'source': 'aws.cloudwatch'}
        context = {}
        
        response = lambda_handler(event, context)
        
        self.assertEqual(response['statusCode'], 200)
        decision = mock_engine.make_scaling_decision.return_value
        self.assertEqual(decision['trigger_mode'], 'reactive')
    
    @patch.dict(os.environ, {
        'EKS_CLUSTER_NAME': 'test-cluster',
        'NAMESPACE': 'test-namespace',
        'DEPLOYMENT_NAME': 'test-deployment'
    })
    @patch('lambda_function.ScalingDecisionEngine')
    def test_lambda_handler_error_handling(self, mock_engine_class):
        """Test Lambda handler error handling"""
        from lambda_function import lambda_handler
        
        # Mock engine to raise exception
        mock_engine_class.side_effect = Exception("Test error")
        
        event = {}
        context = {}
        
        response = lambda_handler(event, context)
        
        self.assertEqual(response['statusCode'], 500)
        self.assertIn('error', response['body'].lower())


if __name__ == '__main__':
    unittest.main()
