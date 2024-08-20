
locals {
  app   = "test-tf-deploy"
  stage = "dev"
}

resource "aws_lambda_function" "api_handler" {
  function_name = "test-tf-deploy-dev"
  runtime       = "python3.9"
  handler       = "app.app"
  memory_size   = 128
  timeout       = 60

  tags = {
    "aws-chalice" = "version=1.31.2:stage=dev:app=test-tf-deploy"
  }

  source_code_hash = filebase64sha256("${path.module}/chalice/deployment.zip")
  filename         = "${path.module}/chalice/deployment.zip"

  environment {
    variables = {
      region_name      = var.region_name
      api_key_pinecone = var.API_key_pinecone
      INDEX_NAME       = var.INDEX_NAME
      ENDPOINT_NAME    = aws_sagemaker_endpoint.hf_endpoint.name
      TABLE_NAME       = aws_dynamodb_table.dynamodb-table-experts.name
      QUEUE_URL        = aws_sqs_queue.sqs_queue.url
    }
  }

  role = aws_iam_role.lambda_execution_role.arn
}

resource "aws_api_gateway_rest_api" "rest_api" {
  name = "test-tf-deploy"
  body = local.chalice_api_swagger

  binary_media_types = [
    "application/octet-stream",
    "application/x-tar",
    "application/zip",
    "audio/basic",
    "audio/ogg",
    "audio/mp4",
    "audio/mpeg",
    "audio/wav",
    "audio/webm",
    "image/png",
    "image/jpg",
    "image/jpeg",
    "image/gif",
    "video/ogg",
    "video/mpeg",
    "video/webm"
  ]

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_deployment" "rest_api" {
  stage_name        = "ai"
  stage_description = md5(local.chalice_api_swagger)
  rest_api_id       = aws_api_gateway_rest_api.rest_api.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "rest_api_invoke" {
  function_name = aws_lambda_function.api_handler.arn
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*"
}

data "aws_caller_identity" "chalice" {}

data "aws_partition" "chalice" {}

data "aws_region" "chalice" {}

output "EndpointURL" {
  value = aws_api_gateway_deployment.rest_api.invoke_url
}

output "RestAPIId" {
  value = aws_api_gateway_rest_api.rest_api.id
}

locals {
  chalice_api_swagger = jsonencode({
    swagger = "2.0"
    info = {
      version = "1.0"
      title   = "test-tf-deploy"
    }
    schemes = ["https"]
    paths = {
      "/register" = {
        post = {
          consumes = ["application/json"]
          produces = ["application/json"]
          responses = {
            "200" = {
              description = "200 response"
              schema      = { "$ref" = "#/definitions/Empty" }
            }
          }
          "x-amazon-apigateway-integration" = {
            responses = { default = { statusCode = "200" } }
            uri                 = aws_lambda_function.api_handler.invoke_arn
            passthroughBehavior = "when_no_match"
            httpMethod          = "POST"
            contentHandling     = "CONVERT_TO_TEXT"
            type                = "aws_proxy"
          }
        }
      }
      "/recommend" = {
        post = {
          consumes = ["application/json"]
          produces = ["application/json"]
          responses = {
            "200" = {
              description = "200 response"
              schema      = { "$ref" = "#/definitions/Empty" }
            }
          }
          "x-amazon-apigateway-integration" = {
            responses = { default = { statusCode = "200" } }
            uri                 = aws_lambda_function.api_handler.invoke_arn
            passthroughBehavior = "when_no_match"
            httpMethod          = "POST"
            contentHandling     = "CONVERT_TO_TEXT"
            type                = "aws_proxy"
          }
        }
      }
    }
    definitions = {
      Empty = {
        type  = "object"
        title = "Empty Schema"
      }
    }
    "x-amazon-apigateway-binary-media-types" = [
      "application/octet-stream",
      "application/x-tar",
      "application/zip",
      "audio/basic",
      "audio/ogg",
      "audio/mp4",
      "audio/mpeg",
      "audio/wav",
      "audio/webm",
      "image/png",
      "image/jpg",
      "image/jpeg",
      "image/gif",
      "video/ogg",
      "video/mpeg",
      "video/webm"
    ]
  })
}
