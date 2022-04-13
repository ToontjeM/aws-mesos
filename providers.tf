terraform {
  required_providers {
    lacework = {
      source  = "lacework/lacework"
    }
    http = {
      source  = "hashicorp/http"
    }
    random = {
      source  = "hashicorp/random"
    }
    null = {
      source  = "hashicorp/null"
    }
    tls = {
      source  = "hashicorp/tls"
    }
    aws = {
      source  = "hashicorp/aws"
    }
    local = {
      source  = "hashicorp/local"
    }
  }
}