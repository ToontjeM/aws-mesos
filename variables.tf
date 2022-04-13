variable "aws_default_region" {
  description = "If you want to change the default region to another region, use this variable. Examples could be us-west-2 or ap-north-1."
  type        = string
  default     = "eu-central-1"
}

variable "lacework_agent_token_name" {
  type = string
  default = "testing"
}
