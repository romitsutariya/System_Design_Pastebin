variable "queue_arn" {
  type = string
}

variable "function_source_path" {
  type = string
}

variable "bucket_prefix" {
  type    = string
  default = "pastebin-voice-output"
}

variable "function_name" {
  type    = string
  default = "pastebin-voice-worker"
}

variable "voice" {
  type    = string
  default = "Joanna"
}

variable "engine" {
  type    = string
  default = "neural"
}

variable "timeout" {
  type    = number
  default = 30
}

resource "aws_s3_bucket" "voice_output" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true
}

resource "aws_iam_role" "lambda_voice_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_voice_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_voice_access" {
  name        = "${var.function_name}-access"
  description = "Allow Polly synth and S3 put, and SQS poll"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "PollySynthesize",
        Effect = "Allow",
        Action = ["polly:SynthesizeSpeech"],
        Resource = "*"
      },
      {
        Sid    = "S3PutVoice",
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:PutObjectAcl"],
        Resource = [aws_s3_bucket.voice_output.arn, "${aws_s3_bucket.voice_output.arn}/*"]
      },
      {
        Sid    = "SQSPollAccess",
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ],
        Resource = var.queue_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_voice_access_attach" {
  role       = aws_iam_role.lambda_voice_role.name
  policy_arn = aws_iam_policy.lambda_voice_access.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content  = file(var.function_source_path)
    filename = "function.py"
  }
}

resource "aws_lambda_function" "voice_worker" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_voice_role.arn
  handler          = "function.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = var.timeout

  environment {
    variables = {
      S3_BUCKET    = aws_s3_bucket.voice_output.bucket
      POLLY_VOICE  = var.voice
      POLLY_ENGINE = var.engine
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_to_voice_lambda" {
  event_source_arn = var.queue_arn
  function_name    = aws_lambda_function.voice_worker.arn
  batch_size       = 5
  enabled          = true
}

output "bucket_name" { value = aws_s3_bucket.voice_output.bucket }
output "lambda_arn" { value = aws_lambda_function.voice_worker.arn }
