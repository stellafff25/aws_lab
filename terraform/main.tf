terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    s3     = "http://localhost:4566"
    lambda = "http://localhost:4566"
    sqs    = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "start" {
  bucket = "s3-start"
}

resource "aws_s3_bucket" "finish" {
  bucket = "s3-finish"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "*",
        Effect = "Allow"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "copy_function" {
  function_name = "copyS3Object"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)
}

resource "aws_s3_bucket_notification" "start_trigger" {
  bucket = aws_s3_bucket.start.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.copy_function.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.start.arn
}

# Optional: SQS queue
resource "aws_sqs_queue" "my_queue" {
  name = "my-queue"
}
