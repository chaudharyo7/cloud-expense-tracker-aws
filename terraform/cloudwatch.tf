# ==============================================================================
# CloudWatch Observability & Alerting Architecture
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Alerting Infrastructure (SNS Topic)
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name         = "expense-tracker-alerts"
  display_name = "Cloud Expense Tracker Alerts"

  tags = {
    Name = "expense-tracker-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ------------------------------------------------------------------------------
# 2. Application Log Metric Filter
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "lambda_errors_filter" {
  name           = "expense-lambda-application-errors"
  log_group_name = aws_cloudwatch_log_group.lambda_log_group.name
  pattern        = "?ERROR ?Error ?Exception ?failed"

  metric_transformation {
    name          = "LambdaApplicationErrors"
    namespace     = "CloudExpenseTracker/Application"
    value         = "1"
    default_value = "0"
  }
}

# ------------------------------------------------------------------------------
# 3. CloudWatch Metric Alarms
# ------------------------------------------------------------------------------

# EC2 Status Check Alarms (Frontend)
resource "aws_cloudwatch_metric_alarm" "ec2_frontend_1_status" {
  alarm_name          = "ec2-frontend-1-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers if frontend-1 fails instance or system status checks for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.frontend_1.id
  }

  tags = {
    Name = "ec2-frontend-1-status-check-failed"
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_frontend_2_status" {
  alarm_name          = "ec2-frontend-2-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers if frontend-2 fails instance or system status checks for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.frontend_2.id
  }

  tags = {
    Name = "ec2-frontend-2-status-check-failed"
  }
}

# EC2 Status Check Alarms (Backend)
resource "aws_cloudwatch_metric_alarm" "ec2_backend_1_status" {
  alarm_name          = "ec2-backend-1-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers if backend-1 fails instance or system status checks for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.backend_1.id
  }

  tags = {
    Name = "ec2-backend-1-status-check-failed"
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_backend_2_status" {
  alarm_name          = "ec2-backend-2-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers if backend-2 fails instance or system status checks for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.backend_2.id
  }

  tags = {
    Name = "ec2-backend-2-status-check-failed"
  }
}

# EC2 CPU Utilization Alarm (Backend Cluster)
resource "aws_cloudwatch_metric_alarm" "ec2_backend_1_cpu_high" {
  alarm_name          = "ec2-backend-1-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Triggers if backend-1 CPU exceeds 85% for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.backend_1.id
  }

  tags = {
    Name = "ec2-backend-1-cpu-high"
  }
}

# ALB Alarms
resource "aws_cloudwatch_metric_alarm" "alb_backend_unhealthy_hosts" {
  alarm_name          = "alb-backend-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers if one or more backend EC2 targets are reported unhealthy by the ALB for 2 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.expense_target_group_backend.arn_suffix
    LoadBalancer = aws_lb.expense_alb.arn_suffix
  }

  tags = {
    Name = "alb-backend-unhealthy-hosts"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_errors" {
  alarm_name          = "alb-target-5xx-errors-elevated"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Triggers if the backend targets return 5 or more 5XX errors within 5 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.expense_alb.arn_suffix
  }

  tags = {
    Name = "alb-target-5xx-errors-elevated"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time_high" {
  alarm_name          = "alb-target-response-time-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 2.0
  alarm_description   = "Triggers if average backend target response time exceeds 2 seconds for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.expense_alb.arn_suffix
  }

  tags = {
    Name = "alb-target-response-time-high"
  }
}

# RDS Alarms
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "rds-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers if RDS CPU utilization exceeds 80% for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.expense_db_instance.identifier
  }

  tags = {
    Name = "rds-cpu-utilization-high"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_low_freeable_memory" {
  alarm_name          = "rds-freeable-memory-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 67108864 # 64 MB
  alarm_description   = "Triggers if RDS freeable memory drops below 64 MB for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.expense_db_instance.identifier
  }

  tags = {
    Name = "rds-freeable-memory-low"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "rds-free-storage-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB (25% of 20GB)
  alarm_description   = "Triggers if RDS free storage drops below 5 GB."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.expense_db_instance.identifier
  }

  tags = {
    Name = "rds-free-storage-low"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "rds-database-connections-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 40
  alarm_description   = "Triggers if RDS database connections exceed 40 for 10 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.expense_db_instance.identifier
  }

  tags = {
    Name = "rds-database-connections-high"
  }
}

# Lambda Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-report-generation-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers if expense report Lambda function fails with unhandled error."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.expense_lambda.function_name
  }

  tags = {
    Name = "lambda-report-generation-errors"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "lambda-report-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers if expense report Lambda execution is throttled."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.expense_lambda.function_name
  }

  tags = {
    Name = "lambda-report-throttles"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_high_duration" {
  alarm_name          = "lambda-report-duration-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 15000 # 15 seconds (50% of 30s timeout)
  alarm_description   = "Triggers if average Lambda execution duration exceeds 15 seconds."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.expense_lambda.function_name
  }

  tags = {
    Name = "lambda-report-duration-high"
  }
}

# NAT Gateway Alarms
resource "aws_cloudwatch_metric_alarm" "nat_gw_port_allocation_error" {
  alarm_name          = "nat-gateway-port-allocation-error"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorPortAllocation"
  namespace           = "AWS/NATGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers if NAT Gateway experiences source port allocation errors."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    NatGatewayId = aws_nat_gateway.main.id
  }

  tags = {
    Name = "nat-gateway-port-allocation-error"
  }
}

resource "aws_cloudwatch_metric_alarm" "nat_gw_packets_drop" {
  alarm_name          = "nat-gateway-packets-drop"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "PacketsDropCount"
  namespace           = "AWS/NATGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Triggers if NAT Gateway drops 10 or more packets in 5 minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    NatGatewayId = aws_nat_gateway.main.id
  }

  tags = {
    Name = "nat-gateway-packets-drop"
  }
}

# ------------------------------------------------------------------------------
# 4. Master CloudWatch Production Dashboard
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "expense_dashboard" {
  dashboard_name = "expense-tracker-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # ========================================================================
      # SECTION 1: OVERALL HEALTH (ALB, Traffic, Latency & Target Health)
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.expense_target_group_frontend.arn_suffix, "LoadBalancer", aws_lb.expense_alb.arn_suffix, { stat = "Average", color = "#2ca02c", label = "Frontend Healthy" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", color = "#d62728", label = "Frontend Unhealthy" }],
            [".", "HealthyHostCount", "TargetGroup", aws_lb_target_group.expense_target_group_backend.arn_suffix, "LoadBalancer", aws_lb.expense_alb.arn_suffix, { stat = "Average", color = "#1f77b4", label = "Backend Healthy" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", color = "#e377c2", label = "Backend Unhealthy" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "OVERALL HEALTH - Target Group Health (Hosts)"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.expense_alb.arn_suffix, { stat = "Sum", color = "#2ca02c", label = "Target 2XX" }],
            [".", "HTTPCode_Target_3XX_Count", ".", ".", { stat = "Sum", color = "#17becf", label = "Target 3XX" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", color = "#ff7f0e", label = "Target 4XX" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", color = "#d62728", label = "Target 5XX" }],
            [".", "HTTPCode_ELB_4XX_Count", ".", ".", { stat = "Sum", color = "#bcbd22", label = "ELB 4XX" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { stat = "Sum", color = "#9467bd", label = "ELB 5XX" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "OVERALL HEALTH - HTTP Response Codes"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.expense_alb.arn_suffix, { stat = "Sum", color = "#1f77b4", label = "ALB Requests" }],
            [".", "TargetResponseTime", ".", ".", { stat = "Average", color = "#ff7f0e", yAxis = "right", label = "Avg Latency (s)" }],
            [".", "TargetResponseTime", ".", ".", { stat = "p95", color = "#aec7e8", yAxis = "right", label = "p95 Latency (s)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "OVERALL HEALTH - Traffic & Response Time"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", aws_lb.expense_alb.arn_suffix, { stat = "Average", color = "#1f77b4", label = "Active Connections" }],
            [".", "NewConnectionCount", ".", ".", { stat = "Sum", color = "#2ca02c", label = "New Connections" }],
            [".", "ProcessedBytes", ".", ".", { stat = "Sum", color = "#7f7f7f", yAxis = "right", label = "Processed Bytes" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB - Connections & Data Processed"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "ConsumedLCUs", "LoadBalancer", aws_lb.expense_alb.arn_suffix, { stat = "Average", color = "#1f77b4", label = "Avg Consumed LCUs" }],
            [".", "ConsumedLCUs", ".", ".", { stat = "Maximum", color = "#ff7f0e", label = "Max Consumed LCUs" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB - Consumed Load Balancer Capacity Units (LCUs)"
          period  = 300
        }
      },

      # ========================================================================
      # SECTION 2: FRONTEND EC2 INSTANCES
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.frontend_1.id, { stat = "Average", color = "#1f77b4", label = "frontend-1 CPU (%)" }],
            [".", ".", ".", aws_instance.frontend_2.id, { stat = "Average", color = "#aec7e8", label = "frontend-2 CPU (%)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "FRONTEND EC2 - CPU Utilization (%)"
          period  = 300
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.frontend_1.id, { stat = "Sum", color = "#1f77b4", label = "frontend-1 NetworkIn" }],
            [".", "NetworkOut", ".", ".", { stat = "Sum", color = "#aec7e8", label = "frontend-1 NetworkOut" }],
            [".", "NetworkIn", ".", aws_instance.frontend_2.id, { stat = "Sum", color = "#2ca02c", label = "frontend-2 NetworkIn" }],
            [".", "NetworkOut", ".", ".", { stat = "Sum", color = "#98df8a", label = "frontend-2 NetworkOut" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "FRONTEND EC2 - Network Traffic (Bytes)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.frontend_1.id, { stat = "Maximum", color = "#d62728", label = "frontend-1 CheckFailed" }],
            [".", "StatusCheckFailed", ".", aws_instance.frontend_2.id, { stat = "Maximum", color = "#ff7f0e", label = "frontend-2 CheckFailed" }],
            [".", "StatusCheckFailed_System", ".", aws_instance.frontend_1.id, { stat = "Maximum", color = "#9467bd", label = "frontend-1 SystemCheck" }],
            [".", "StatusCheckFailed_System", ".", aws_instance.frontend_2.id, { stat = "Maximum", color = "#8c564b", label = "frontend-2 SystemCheck" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "FRONTEND EC2 - Status Checks"
          period  = 300
          yAxis = {
            left = { min = 0, max = 1 }
          }
        }
      },

      # ========================================================================
      # SECTION 3: BACKEND EC2 INSTANCES
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.backend_1.id, { stat = "Average", color = "#2ca02c", label = "backend-1 CPU (%)" }],
            [".", ".", ".", aws_instance.backend_2.id, { stat = "Average", color = "#98df8a", label = "backend-2 CPU (%)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "BACKEND EC2 - CPU Utilization (%)"
          period  = 300
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.backend_1.id, { stat = "Sum", color = "#1f77b4", label = "backend-1 NetworkIn" }],
            [".", "NetworkOut", ".", ".", { stat = "Sum", color = "#aec7e8", label = "backend-1 NetworkOut" }],
            [".", "NetworkIn", ".", aws_instance.backend_2.id, { stat = "Sum", color = "#2ca02c", label = "backend-2 NetworkIn" }],
            [".", "NetworkOut", ".", ".", { stat = "Sum", color = "#98df8a", label = "backend-2 NetworkOut" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "BACKEND EC2 - Network Traffic (Bytes)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 18
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.backend_1.id, { stat = "Maximum", color = "#d62728", label = "backend-1 CheckFailed" }],
            [".", "StatusCheckFailed", ".", aws_instance.backend_2.id, { stat = "Maximum", color = "#ff7f0e", label = "backend-2 CheckFailed" }],
            [".", "StatusCheckFailed_System", ".", aws_instance.backend_1.id, { stat = "Maximum", color = "#9467bd", label = "backend-1 SystemCheck" }],
            [".", "StatusCheckFailed_System", ".", aws_instance.backend_2.id, { stat = "Maximum", color = "#8c564b", label = "backend-2 SystemCheck" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "BACKEND EC2 - Status Checks"
          period  = 300
          yAxis = {
            left = { min = 0, max = 1 }
          }
        }
      },

      # ========================================================================
      # SECTION 4: RDS POSTGRESQL DATABASE
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.expense_db_instance.identifier, { stat = "Average", color = "#1f77b4", label = "CPU Utilization (%)" }],
            [".", "DatabaseConnections", ".", ".", { stat = "Average", color = "#ff7f0e", yAxis = "right", label = "DB Connections" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS - CPU Utilization & Active Connections"
          period  = 300
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 24
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.expense_db_instance.identifier, { stat = "Average", color = "#2ca02c", label = "Free Storage (Bytes)" }],
            [".", "FreeableMemory", ".", ".", { stat = "Average", color = "#9467bd", yAxis = "right", label = "Freeable Memory (Bytes)" }],
            [".", "SwapUsage", ".", ".", { stat = "Average", color = "#d62728", yAxis = "right", label = "Swap Usage (Bytes)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS - Storage, Free Memory & Swap"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 24
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", aws_db_instance.expense_db_instance.identifier, { stat = "Average", color = "#1f77b4", label = "Read IOPS" }],
            [".", "WriteIOPS", ".", ".", { stat = "Average", color = "#ff7f0e", label = "Write IOPS" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS - Read & Write IOPS"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 30
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReadThroughput", "DBInstanceIdentifier", aws_db_instance.expense_db_instance.identifier, { stat = "Average", color = "#1f77b4", label = "Read Throughput (B/s)" }],
            [".", "WriteThroughput", ".", ".", { stat = "Average", color = "#ff7f0e", label = "Write Throughput (B/s)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS - Throughput (Bytes/sec)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 30
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", aws_db_instance.expense_db_instance.identifier, { stat = "Average", color = "#1f77b4", label = "Read Latency (s)" }],
            [".", "WriteLatency", ".", ".", { stat = "Average", color = "#ff7f0e", label = "Write Latency (s)" }],
            [".", "DiskQueueDepth", ".", ".", { stat = "Average", color = "#d62728", yAxis = "right", label = "Disk Queue Depth" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS - Latency & Disk Queue Depth"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 30
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "NetworkReceiveThroughput", "DBInstanceIdentifier", aws_db_instance.expense_db_instance.identifier, { stat = "Average", color = "#1f77b4", label = "Receive (B/s)" }],
            [".", "NetworkTransmitThroughput", ".", ".", { stat = "Average", color = "#2ca02c", label = "Transmit (B/s)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS - Network Throughput (Bytes/sec)"
          period  = 300
        }
      },

      # ========================================================================
      # SECTION 5: LAMBDA REPORT SERVICE
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 36
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.expense_lambda.function_name, { stat = "Sum", color = "#2ca02c", label = "Invocations" }],
            [".", "Errors", ".", ".", { stat = "Sum", color = "#d62728", label = "Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "LAMBDA - Invocations & Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 36
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.expense_lambda.function_name, { stat = "Average", color = "#1f77b4", label = "Avg Duration (ms)" }],
            [".", "Duration", ".", ".", { stat = "p95", color = "#aec7e8", label = "p95 Duration (ms)" }],
            [".", "Throttles", ".", ".", { stat = "Sum", color = "#ff7f0e", yAxis = "right", label = "Throttles" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "LAMBDA - Duration (ms) & Throttles"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 36
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", aws_lambda_function.expense_lambda.function_name, { stat = "Maximum", color = "#1f77b4", label = "Concurrent Executions" }],
            [".", "UnreservedConcurrentExecutions", ".", ".", { stat = "Average", color = "#7f7f7f", label = "Unreserved Concurrency" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "LAMBDA - Concurrency"
          period  = 300
        }
      },

      # ========================================================================
      # SECTION 6: NAT GATEWAY
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 42
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/NATGateway", "BytesInFromSource", "NatGatewayId", aws_nat_gateway.main.id, { stat = "Sum", color = "#1f77b4", label = "BytesInFromSource" }],
            [".", "BytesOutToDestination", ".", ".", { stat = "Sum", color = "#aec7e8", label = "BytesOutToDest" }],
            [".", "BytesInFromDestination", ".", ".", { stat = "Sum", color = "#2ca02c", label = "BytesInFromDest" }],
            [".", "BytesOutToSource", ".", ".", { stat = "Sum", color = "#98df8a", label = "BytesOutToSource" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "NAT GATEWAY - Data Transfer (Bytes)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 42
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/NATGateway", "ActiveConnectionCount", "NatGatewayId", aws_nat_gateway.main.id, { stat = "Average", color = "#1f77b4", label = "Active Connections" }],
            [".", "ConnectionAttemptCount", ".", ".", { stat = "Sum", color = "#2ca02c", label = "Connection Attempts" }],
            [".", "ConnectionEstablishedCount", ".", ".", { stat = "Sum", color = "#17becf", label = "Connections Established" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "NAT GATEWAY - Connection Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 42
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/NATGateway", "ErrorPortAllocation", "NatGatewayId", aws_nat_gateway.main.id, { stat = "Sum", color = "#d62728", label = "Port Allocation Errors" }],
            [".", "PacketsDropCount", ".", ".", { stat = "Sum", color = "#ff7f0e", label = "Dropped Packets" }],
            [".", "IdleTimeoutCount", ".", ".", { stat = "Sum", color = "#9467bd", label = "Idle Timeouts" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "NAT GATEWAY - Errors, Drops & Timeouts"
          period  = 300
        }
      },

      # ========================================================================
      # SECTION 7: S3 REPORT STORAGE
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 48
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.expense_bucket.bucket, "StorageType", "StandardStorage", { stat = "Average", color = "#1f77b4", label = "Standard Bucket Size (Bytes)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "S3 - Report Bucket Storage Size (Daily)"
          period  = 86400
          start   = "-P14D"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 48
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", aws_s3_bucket.expense_bucket.bucket, "StorageType", "AllStorageTypes", { stat = "Average", color = "#2ca02c", label = "Total Objects Count" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "S3 - Report Bucket Object Count (Daily)"
          period  = 86400
          start   = "-P14D"
        }
      },

      # ========================================================================
      # SECTION 8: API GATEWAY (ROLLBACK INFRASTRUCTURE)
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 54
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.expense_api.id, { stat = "Sum", color = "#1f77b4", label = "Requests" }],
            [".", "4xx", ".", ".", { stat = "Sum", color = "#ff7f0e", label = "4XX Errors" }],
            [".", "5xx", ".", ".", { stat = "Sum", color = "#d62728", label = "5XX Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "API GATEWAY (ROLLBACK PATH) - Requests & Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 54
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", aws_apigatewayv2_api.expense_api.id, { stat = "Average", color = "#1f77b4", label = "Avg Latency (ms)" }],
            [".", "Latency", ".", ".", { stat = "p95", color = "#aec7e8", label = "p95 Latency (ms)" }],
            [".", "IntegrationLatency", ".", ".", { stat = "Average", color = "#2ca02c", label = "Avg Integration Latency (ms)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "API GATEWAY (ROLLBACK PATH) - Latencies (ms)"
          period  = 300
        }
      },

      # ========================================================================
      # SECTION 9: APPLICATION OPERATIONAL METRICS & ARCHITECTURE NOTES
      # ========================================================================
      {
        type   = "metric"
        x      = 0
        y      = 60
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["CloudExpenseTracker/Application", "LambdaApplicationErrors", { stat = "Sum", color = "#d62728", label = "Lambda App Errors (Log Filter)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "APPLICATION - Lambda Log Error Metric Filter"
          period  = 300
        }
      },
      {
        type   = "text"
        x      = 12
        y      = 60
        width  = 12
        height = 6
        properties = {
          markdown = "### Architecture Observability & Baseline Policies\n- **Production API Path**: Browser &rarr; ALB (`/api/*`) &rarr; Backend EC2 (`gunicorn`) &rarr; Lambda/RDS/S3.\n- **EC2 Monitoring**: Basic Monitoring (5-min resolution) active at zero additional cost. OS disk/memory require CloudWatch Agent ($0.30/metric/mo).\n- **RDS Monitoring**: Native RDS CloudWatch metrics active at zero cost. Enhanced Monitoring disabled to prevent extra log ingestion charges.\n- **S3 Observability**: Native daily storage metrics active for free. Detailed S3 request metrics require paid filters ($0.30/filter/mo).\n- **Log Retention**: Strictly enforced at 14 days across all log groups to minimize CloudWatch storage costs."
        }
      }
    ]
  })
}
