terraform {
  required_version = ">= 0.15"
  required_providers {
    pinecone = {
      source = "pinecone-io/pinecone"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.63"
    }

  }
}
provider "aws" {
  region = "us-east-1"
}

provider "pinecone" {
  api_key=var.API_key_pinecone


}


