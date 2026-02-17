"""
Intelligent Autoscaling Controller for AI-Assisted Claims Processing
"""
import json
import os
import boto3
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import statistics

# Initialize AWS clients
cloudwatch = boto3.client('cloudwatch')
eks = boto3.client('eks')

# Configuration from environment variables
CLUSTER_NAME = os.environ.get('EKS_CLUSTER_NAME', 'test-cluster')
NAMESPACE = os.environ.get('NAMESPACE', 'materclaims')
DEPLOYMENT_NAME = os.environ.get('DEPLOYMENT_NAME', 'claim-status-api')
MIN_REPLICAS = int(os.environ.get('MIN_REPLICAS', '2'))
MAX_REPLICAS = int(os.environ.get('MAX_REPLICAS', '10'))
METRIC_WINDOW_MINUTES = int(os.environ.get('METRIC_WINDOW_MINUTES', '10'))
TREND_THRESHOLD = float(os.environ.get('TREND_THRESHOLD', '0.15'))  # 15% increase = trend
NOISE_FILTER_THRESHOLD = float(os.environ.get('NOISE_FILTER_THRESHOLD', '0.05'))  # 5% variation = noise


class MetricAnalyzer:
    """Analyzes metrics and filters noise"""
    
    def __init__(self, namespace: str, metric_name: str, dimensions: List[Dict]):
        self.namespace = namespace
        self.metric_name = metric_name
        self.dimensions = dimensions
    
    def get_metric_statistics(self, period_minutes: int = 10, statistic: str = 'Average') -> List[float]:
        """Retrieve metric values over the specified period"""
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=period_minutes)
        
        try:
            response = cloudwatch.get_metric_statistics(
                Namespace=self.namespace,
                MetricName=self.metric_name,
                Dimensions=self.dimensions,
                StartTime=start_time,
                EndTime=end_time,
                Period=60,  # 1-minute granularity
                Statistics=[statistic]
            )
            
            datapoints = sorted(response.get('Datapoints', []), key=lambda x: x['Timestamp'])
            return [dp[statistic] for dp in datapoints]
        except Exception as e:
            print(f"Error retrieving metric {self.metric_name}: {str(e)}")
            return []
    
    def calculate_trend(self, values: List[float]) -> Tuple[str, float]:
        """
        Calculate trend direction and magnitude
        Returns: (trend_direction, trend_magnitude)
        """
        if len(values) < 3:
            return "stable", 0.0
        
        # Calculate linear regression slope
        n = len(values)
        x = list(range(n))
        x_mean = statistics.mean(x)
        y_mean = statistics.mean(values)
        
        numerator = sum((x[i] - x_mean) * (values[i] - y_mean) for i in range(n))
        denominator = sum((x[i] - x_mean) ** 2 for i in range(n))
        
        if denominator == 0:
            return "stable", 0.0
        
        slope = numerator / denominator
        magnitude = abs(slope / y_mean) if y_mean != 0 else 0
        
        if magnitude < TREND_THRESHOLD:
            return "stable", magnitude
        elif slope > 0:
            return "increasing", magnitude
        else:
            return "decreasing", magnitude
    
    def filter_noise(self, values: List[float]) -> bool:
        """
        Determine if variation is noise or signal
        Returns True if signal, False if noise
        """
        if len(values) < 2:
            return False
        
        mean_val = statistics.mean(values)
        if mean_val == 0:
            return False
        
        stdev = statistics.stdev(values)
        coefficient_of_variation = stdev / mean_val
        
        # High variation relative to mean = signal, not noise
        return coefficient_of_variation > NOISE_FILTER_THRESHOLD


class ScalingDecisionEngine:
    """Makes intelligent scaling decisions based on multiple signals"""
    
    def __init__(self, cluster_name: str, namespace: str, deployment: str):
        self.cluster_name = cluster_name
        self.namespace = namespace
        self.deployment = deployment
        self.metrics_cache = {}
    
    def collect_metrics(self) -> Dict[str, Dict]:
        """Collect all relevant metrics"""
        metrics = {}
        
        # CPU Utilization
        cpu_analyzer = MetricAnalyzer(
            'ContainerInsights',
            'pod_cpu_utilization',
            [
                {'Name': 'ClusterName', 'Value': self.cluster_name},
                {'Name': 'Namespace', 'Value': self.namespace}
            ]
        )
        cpu_values = cpu_analyzer.get_metric_statistics(METRIC_WINDOW_MINUTES)
        metrics['cpu'] = {
            'values': cpu_values,
            'current': cpu_values[-1] if cpu_values else 0,
            'trend': cpu_analyzer.calculate_trend(cpu_values),
            'is_signal': cpu_analyzer.filter_noise(cpu_values)
        }
        
        # Memory Utilization
        mem_analyzer = MetricAnalyzer(
            'ContainerInsights',
            'pod_memory_utilization',
            [
                {'Name': 'ClusterName', 'Value': self.cluster_name},
                {'Name': 'Namespace', 'Value': self.namespace}
            ]
        )
        mem_values = mem_analyzer.get_metric_statistics(METRIC_WINDOW_MINUTES)
        metrics['memory'] = {
            'values': mem_values,
            'current': mem_values[-1] if mem_values else 0,
            'trend': mem_analyzer.calculate_trend(mem_values),
            'is_signal': mem_analyzer.filter_noise(mem_values)
        }
        
        # API Latency (from custom CloudWatch metrics)
        latency_analyzer = MetricAnalyzer(
            'ClaimStatusAPI',
            'APILatency',
            [
                {'Name': 'Service', 'Value': 'claim-status-api'},
                {'Name': 'Namespace', 'Value': self.namespace}
            ]
        )
        latency_values = latency_analyzer.get_metric_statistics(METRIC_WINDOW_MINUTES, 'Average')
        metrics['latency'] = {
            'values': latency_values,
            'current': latency_values[-1] if latency_values else 0,
            'trend': latency_analyzer.calculate_trend(latency_values),
            'is_signal': latency_analyzer.filter_noise(latency_values)
        }
        
        # Bedrock Inference Duration
        bedrock_analyzer = MetricAnalyzer(
            'ClaimStatusAPI',
            'BedrockInferenceDuration',
            [
                {'Name': 'Service', 'Value': 'claim-status-api'},
                {'Name': 'Model', 'Value': 'nova-lite'}
            ]
        )
        bedrock_values = bedrock_analyzer.get_metric_statistics(METRIC_WINDOW_MINUTES, 'Average')
        metrics['bedrock'] = {
            'values': bedrock_values,
            'current': bedrock_values[-1] if bedrock_values else 0,
            'trend': bedrock_analyzer.calculate_trend(bedrock_values),
            'is_signal': bedrock_analyzer.filter_noise(bedrock_values)
        }
        
        return metrics
    
    def make_scaling_decision(self, metrics: Dict[str, Dict]) -> Dict:
        """
        Correlate multiple signals to make an intelligent scaling decision
        Returns decision with reasoning
        """
        decision = {
            'action': 'none',
            'reason': [],
            'mode': 'proactive',
            'metrics_evaluated': {},
            'timestamp': datetime.utcnow().isoformat()
        }
        
        scale_up_signals = 0
        scale_down_signals = 0
        
        # Evaluate each metric
        for metric_name, metric_data in metrics.items():
            trend_direction, trend_magnitude = metric_data['trend']
            is_signal = metric_data['is_signal']
            current_value = metric_data['current']
            
            decision['metrics_evaluated'][metric_name] = {
                'current': current_value,
                'trend': trend_direction,
                'magnitude': trend_magnitude,
                'is_signal': is_signal
            }
            
            # Skip if it's just noise
            if not is_signal:
                decision['reason'].append(f"{metric_name}: Filtered as noise (variation < {NOISE_FILTER_THRESHOLD})")
                continue
            
            # CPU analysis
            if metric_name == 'cpu':
                if current_value > 70 and trend_direction == 'increasing':
                    scale_up_signals += 1
                    decision['reason'].append(f"CPU: High utilization ({current_value}%) with increasing trend")
                elif current_value < 30 and trend_direction == 'decreasing':
                    scale_down_signals += 1
                    decision['reason'].append(f"CPU: Low utilization ({current_value}%) with decreasing trend")
            
            # Memory analysis
            if metric_name == 'memory':
                if current_value > 80 and trend_direction == 'increasing':
                    scale_up_signals += 1
                    decision['reason'].append(f"Memory: High utilization ({current_value}%) with increasing trend")
                elif current_value < 40 and trend_direction == 'decreasing':
                    scale_down_signals += 1
                    decision['reason'].append(f"Memory: Low utilization ({current_value}%) with decreasing trend")
            
            # API Latency analysis (AI workload context-aware)
            if metric_name == 'latency':
                # For Bedrock-heavy workloads, expect higher baseline latency
                if current_value > 5000 and trend_direction == 'increasing':  # >5s latency
                    scale_up_signals += 1
                    decision['reason'].append(f"API Latency: Sustained high latency ({current_value}ms) with increasing trend")
                    decision['mode'] = 'reactive'  # Immediate action needed
            
            # Bedrock inference duration
            if metric_name == 'bedrock':
                if current_value > 3000 and trend_direction == 'increasing':  # >3s inference time
                    scale_up_signals += 1
                    decision['reason'].append(f"Bedrock: Inference duration ({current_value}ms) increasing, likely due to concurrency limits")
        
        # Make final decision based on signal correlation
        if scale_up_signals >= 2:
            decision['action'] = 'scale_up'
            decision['reason'].insert(0, f"Multi-metric evaluation: {scale_up_signals} scale-up signals detected")
        elif scale_down_signals >= 2:
            decision['action'] = 'scale_down'
            decision['reason'].insert(0, f"Multi-metric evaluation: {scale_down_signals} scale-down signals detected")
        else:
            decision['action'] = 'none'
            decision['reason'].insert(0, "No correlated signals detected for scaling action")
        
        return decision
    
    def publish_custom_metric(self, metric_name: str, value: float, unit: str = 'None'):
        """Publish custom CloudWatch metric for observability"""
        try:
            cloudwatch.put_metric_data(
                Namespace='IntelligentAutoscaler',
                MetricData=[
                    {
                        'MetricName': metric_name,
                        'Value': value,
                        'Unit': unit,
                        'Timestamp': datetime.utcnow(),
                        'Dimensions': [
                            {'Name': 'ClusterName', 'Value': self.cluster_name},
                            {'Name': 'Namespace', 'Value': self.namespace},
                            {'Name': 'Deployment', 'Value': self.deployment}
                        ]
                    }
                ]
            )
        except Exception as e:
            print(f"Error publishing metric {metric_name}: {str(e)}")
    
    def execute_scaling_action(self, decision: Dict) -> bool:
        """
        Execute the scaling decision by updating HPA or deployment
        Note: This is a simplified implementation that publishes scaling recommendations
        In production, this would integrate with K8s API to update HPA min/max or deployment replicas
        """
        action = decision['action']
        
        if action == 'none':
            self.publish_custom_metric('ScalingDecision', 0)
            return True
        
        # Publish scaling decision metric
        scaling_value = 1 if action == 'scale_up' else -1
        self.publish_custom_metric('ScalingDecision', scaling_value)
        
        # Log the decision with full context
        print(json.dumps({
            'decision': action,
            'mode': decision['mode'],
            'reasoning': decision['reason'],
            'metrics': decision['metrics_evaluated'],
            'timestamp': decision['timestamp']
        }, indent=2))
        
        return True


def lambda_handler(event, context):
    """
    Lambda handler - triggered every 5 minutes by CloudWatch Events
    Implements dual trigger model: reactive (alarms) and proactive (scheduled)
    """
    
    try:
        # Determine if this is a reactive (alarm) or proactive (scheduled) trigger
        trigger_mode = 'proactive'
        if 'source' in event and event['source'] == 'aws.cloudwatch':
            trigger_mode = 'reactive'
        
        print(f"Intelligent Autoscaler triggered in {trigger_mode} mode")
        
        # Initialize decision engine
        engine = ScalingDecisionEngine(CLUSTER_NAME, NAMESPACE, DEPLOYMENT_NAME)
        
        # Collect and analyze metrics
        metrics = engine.collect_metrics()
        
        # Make scaling decision
        decision = engine.make_scaling_decision(metrics)
        decision['trigger_mode'] = trigger_mode
        
        # Execute scaling action
        success = engine.execute_scaling_action(decision)
        
        # Publish observability metrics
        engine.publish_custom_metric('ExecutionSuccess', 1 if success else 0)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Autoscaling evaluation completed',
                'decision': decision
            })
        }
        
    except Exception as e:
        print(f"Error in autoscaling controller: {str(e)}")
        
        # Publish failure metric
        try:
            cloudwatch.put_metric_data(
                Namespace='IntelligentAutoscaler',
                MetricData=[
                    {
                        'MetricName': 'ExecutionFailure',
                        'Value': 1,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow()
                    }
                ]
            )
        except:
            pass
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Autoscaling evaluation failed',
                'error': str(e)
            })
        }
