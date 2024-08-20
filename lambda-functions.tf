# Créer le rôle IAM avec les politiques nécessaires
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_execution_policy" {
  name   = "step-function-execution-policy"
  role   = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "states:StartExecution",
        Resource = "${aws_sfn_state_machine.sfn_state_machine.arn}"
      }
    ]
  })
}

# Attacher les politiques nécessaires au rôle IAM
resource "aws_iam_role_policy_attachment" "dynamodb" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "sqs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

resource "aws_iam_role_policy_attachment" "api_gateway" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
}


resource "aws_iam_role_policy_attachment" "step-function" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}



# Créer la fonction Lambda
resource "aws_lambda_function" "data-retrieval" {
  function_name = "data-retrieval"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"

  filename      = "${path.module}/lambda_functions/data-retrieval.zip"  
  source_code_hash = filebase64sha256("${path.module}/lambda_functions/data-retrieval.zip")  
  timeout = 600
  memory_size=400
  environment {
    variables = {
    
    table_dynamo_name=aws_dynamodb_table.dynamodb-table-experts.name
    bucket_name=aws_s3_bucket.images_bucket.bucket

    }
  }
}


###################################################
### embedding, and storage
###################################################

# Créer la fonction Lambda
resource "aws_lambda_function" "embedding_store" {
  function_name = "embedding_store"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"

  filename      = "${path.module}/lambda_functions/embedding_store.zip"  
  source_code_hash = filebase64sha256("${path.module}/lambda_functions/embedding_store.zip")  
  timeout = 600
  memory_size=400
  environment {
    variables = {
    ENDPOINT_NAME=aws_sagemaker_endpoint.hf_endpoint.name     /*aws_sagemaker_endpoint.hf_endpoint.name*/
    INDEX_NAME = var.INDEX_NAME
    API_key_pinecone=var.API_key_pinecone
    bucket_name=aws_s3_bucket.images_bucket.bucket

    }
  }
}


###########################################
#### declenche step function:

resource "aws_lambda_function" "trigger-step-function" {
  function_name = "trigger-step-function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"

  filename      = "${path.module}/lambda_functions/trigger-step_function.zip"  
  source_code_hash = filebase64sha256("${path.module}/lambda_functions/trigger-step_function.zip")  
  timeout = 30
 
  environment {
    variables = {
    arn_step_function = aws_sfn_state_machine.sfn_state_machine.arn
  

    }
  }
}

resource "aws_lambda_event_source_mapping" "event-sqs-lambda-trigger-step-function" {
  event_source_arn = aws_sqs_queue.sqs_queue.arn
  function_name    = aws_lambda_function.trigger-step-function.arn

}













/*
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"
}*/