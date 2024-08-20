

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "state-machine"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("${path.module}/state-machine/state-machine.json", {

    lambda_arn_DLQ_url = {"data-retrieval":aws_lambda_function.data-retrieval.arn,
    
    "Dlq-embedding_url":aws_sqs_queue.queue_deadletter_embedding.url,"embedding_store":aws_lambda_function.embedding_store.arn,
    "Dlq-extract_url":aws_sqs_queue.queue_deadletter_lambda_extract.url
    }
  }
  ) 
}


################################
####  Role step functions
################################


# Définir la politique IAM pour Step Functions
resource "aws_iam_policy" "step_functions_policy" {
  name        = "stepFunctionsPolicy"
  description = "Policy for Step Functions to interact with Lambda, SQS, and X-Ray"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
       {
        Effect: "Allow",
        Action: "states:StartExecution",
        Resource: "${aws_sfn_state_machine.sfn_state_machine.arn}"
        },
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          "${aws_lambda_function.data-retrieval.arn}:*",
          "${aws_lambda_function.embedding_store.arn}:*",
          "${aws_lambda_function.data-retrieval.arn}",
          "${aws_lambda_function.embedding_store.arn}"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = [
          "${aws_sqs_queue.queue_deadletter_embedding.arn}",
           "${aws_sqs_queue.queue_deadletter_lambda_extract.arn}"
         
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ],
        Resource = "*"
      }
    ]
  })
}

# Créer un rôle IAM pour Step Functions
resource "aws_iam_role" "step_functions_role" {
  name               = "stepFunctionsRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "states.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attacher la politique IAM au rôle IAM
resource "aws_iam_role_policy_attachment" "step_functions_policy_attachment" {
  policy_arn = aws_iam_policy.step_functions_policy.arn
  role       = aws_iam_role.step_functions_role.name
}

resource "aws_iam_role_policy_attachment" "s3_step-function" {
  role       = aws_iam_role.step_functions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}