
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "bank-statement-analytics"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain Lambda logs"
  type        = number
  default     = 14
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for Claude"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

variable "s3_trigger_prefix" {
  description = "S3 object key prefix to trigger Lambda"
  type        = string
  default     = ""
}

variable "s3_trigger_suffix" {
  description = "S3 object key suffix to trigger Lambda"
  type        = string
  default     = ".csv"
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}