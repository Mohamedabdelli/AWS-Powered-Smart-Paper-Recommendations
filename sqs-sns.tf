resource "aws_sqs_queue" "sqs_queue" {
  name = "main-sqs-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.queue_deadletter_main.arn
    maxReceiveCount     = 4
  })
}

resource "aws_sqs_queue" "queue_deadletter_main" {
  name = "deadletter-queue-main-sqs"
}

resource "aws_sqs_queue" "queue_deadletter_lambda_extract" {
  name = "deadletter-queue-extract"
}

resource "aws_sqs_queue" "queue_deadletter_embedding" {
  name = "deadletter-queue-embedding"
}


output "url-sqs" {
    value = {"url_sqs":aws_sqs_queue.sqs_queue.url,

    "url_sqs_deadletter-extract":aws_sqs_queue.queue_deadletter_lambda_extract.url
    "url_sqs_deadletter-embedding":aws_sqs_queue.queue_deadletter_embedding.url
    "url_sqs_deadletter":aws_sqs_queue.queue_deadletter_main.url


    }
  
}

