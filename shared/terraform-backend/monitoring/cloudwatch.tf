# ========================================
# CloudWatch 모니터링 및 알람
# S3 및 DynamoDB State 관리 모니터링
# ========================================

# SNS Topic for Alerts
resource "aws_sns_topic" "terraform_state_alerts" {
  name = "terraform-state-alerts"
  
  tags = {
    Purpose = "terraform-state-monitoring"
  }
}

resource "aws_sns_topic_subscription" "terraform_state_alerts_email" {
  topic_arn = aws_sns_topic.terraform_state_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ========================================
# S3 Bucket Monitoring
# ========================================

# S3 버킷 크기 모니터링
resource "aws_cloudwatch_metric_alarm" "s3_bucket_size" {
  alarm_name          = "terraform-state-bucket-size"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400"  # 24시간
  statistic           = "Average"
  threshold           = 1073741824  # 1GB
  alarm_description   = "Alert when terraform state bucket exceeds 1GB"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]

  dimensions = {
    BucketName = aws_s3_bucket.terraform_state.id
    StorageType = "StandardStorage"
  }
}

# S3 버킷 객체 수 모니터링
resource "aws_cloudwatch_metric_alarm" "s3_object_count" {
  alarm_name          = "terraform-state-object-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "86400"
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Alert when number of objects exceeds 1000"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]

  dimensions = {
    BucketName = aws_s3_bucket.terraform_state.id
    StorageType = "AllStorageTypes"
  }
}

# S3 버킷 요청 에러 모니터링
resource "aws_cloudwatch_metric_alarm" "s3_4xx_errors" {
  alarm_name          = "terraform-state-s3-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert on S3 4xx errors"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = aws_s3_bucket.terraform_state.id
  }
}

# ========================================
# DynamoDB Monitoring
# ========================================

# DynamoDB 읽기 용량 사용률
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttle" {
  alarm_name          = "terraform-lock-table-read-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when DynamoDB read requests are throttled"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.terraform_locks.name
  }
}

# DynamoDB 쓰기 용량 사용률
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttle" {
  alarm_name          = "terraform-lock-table-write-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when DynamoDB write requests are throttled"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.terraform_locks.name
  }
}

# DynamoDB 시스템 에러
resource "aws_cloudwatch_metric_alarm" "dynamodb_system_errors" {
  alarm_name          = "terraform-lock-table-system-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert on DynamoDB system errors"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.terraform_locks.name
  }
}

# ========================================
# State Lock Monitoring
# ========================================

# Lock 지속 시간 모니터링 (커스텀 메트릭)
resource "aws_cloudwatch_log_metric_filter" "long_running_locks" {
  name           = "terraform-long-running-locks"
  pattern        = "[time, request_id, lock_id, duration > 300]"
  log_group_name = aws_cloudwatch_log_group.terraform_state_logs.name

  metric_transformation {
    name      = "LongRunningLocks"
    namespace = "TerraformState"
    value     = "1"
    
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "long_running_locks" {
  alarm_name          = "terraform-long-running-locks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "LongRunningLocks"
  namespace           = "TerraformState"
  period              = "300"
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when terraform lock is held for more than 5 minutes"
  alarm_actions       = [aws_sns_topic.terraform_state_alerts.arn]
  treat_missing_data  = "notBreaching"
}

# ========================================
# CloudWatch Dashboard
# ========================================

resource "aws_cloudwatch_dashboard" "terraform_state" {
  dashboard_name = "terraform-state-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", { stat = "Average", label = "Bucket Size" }],
            [".", "NumberOfObjects", { stat = "Average", label = "Object Count", yAxis = "right" }]
          ]
          view    = "timeSeries"
          region  = var.aws_region
          title   = "S3 Bucket Metrics"
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "DynamoDB Capacity Usage"
          period = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/S3", "4xxErrors", { stat = "Sum", label = "4xx Errors" }],
            [".", "5xxErrors", { stat = "Sum", label = "5xx Errors" }]
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "S3 Errors"
          period = 300
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.terraform_state_logs.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region  = var.aws_region
          title   = "Recent Terraform State Activity"
        }
      }
    ]
  })
}

# ========================================
# CloudWatch Logs
# ========================================

resource "aws_cloudwatch_log_group" "terraform_state_logs" {
  name              = "/aws/terraform/state"
  retention_in_days = 30
  
  kms_key_id = var.kms_key_arn  # 로그 암호화

  tags = {
    Purpose = "terraform-state-logging"
  }
}
