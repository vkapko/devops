# ── IAM Role ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_scheduler" {
  name = "ApexTraderEC2SchedulerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_scheduler" {
  name = "ApexTraderEC2SchedulerPolicy"
  role = aws_iam_role.ec2_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:StartInstances", "ec2:StopInstances", "ec2:DescribeInstances", "ec2:DescribeInstanceStatus"]
        Resource = "*"
      }
    ]
  })
}

# ── Lambda Function ──────────────────────────────────────────────────────────
resource "aws_lambda_function" "ec2_scheduler" {
  function_name = "ApexTraderEC2Scheduler"
  role          = aws_iam_role.ec2_scheduler.arn
  runtime       = "python3.11"
  handler       = "lambda_ec2_scheduler.lambda_handler"
  timeout       = 60
  memory_size   = 128

  environment {
    variables = {
      INSTANCE_ID = "i-0046b1c6b0e0d0ad0"
    }
  }

  # Code is managed outside Terraform (deployed via console/CI).
  filename = "placeholder.zip"

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  tags = {
    Environment = var.environment
  }
}

# ── EventBridge Rules ────────────────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "apextrader_start_weekdays" {
  name                = "apextrader-start-weekdays"
  description         = "Start ApexTrader EC2 instance Mon-Fri at 7:30 AM EST"
  schedule_expression = "cron(30 11 ? * MON-FRI *)"
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_rule" "apextrader_stop_weekdays" {
  name                = "apextrader-stop-weekdays"
  description         = "Stop ApexTrader EC2 instance Mon-Fri at 5 PM EST"
  schedule_expression = "cron(0 21 ? * MON-FRI *)"
  state               = "ENABLED"
}

# ── EventBridge Targets ──────────────────────────────────────────────────────
resource "aws_cloudwatch_event_target" "apextrader_start" {
  rule      = aws_cloudwatch_event_rule.apextrader_start_weekdays.name
  target_id = "1"
  arn       = aws_lambda_function.ec2_scheduler.arn
  input     = jsonencode({ action = "start" })
}

resource "aws_cloudwatch_event_target" "apextrader_stop" {
  rule      = aws_cloudwatch_event_rule.apextrader_stop_weekdays.name
  target_id = "1"
  arn       = aws_lambda_function.ec2_scheduler.arn
  input     = jsonencode({ action = "stop" })
}

# ── Lambda Permissions (allow EventBridge to invoke Lambda) ──────────────────
resource "aws_lambda_permission" "allow_start_rule" {
  statement_id  = "apextrader-start-weekdays"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.apextrader_start_weekdays.arn
}

resource "aws_lambda_permission" "allow_stop_rule" {
  statement_id  = "apextrader-stop-weekdays"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.apextrader_stop_weekdays.arn
}
