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
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  s3_force_path_style         = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  endpoints {
    s3     = "http://localhost:4566"
    lambda = "http://localhost:4566"
    iam    = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "start" {
  bucket = "s3-start"
}

resource "aws_s3_bucket" "finish" {
  bucket = "s3-finish"

  lifecycle_rule {
    id      = "expire-objects"
    enabled = true

    expiration {
      days = 30
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_s3_attach" {
  name       = "lambda_s3_policy_attachment"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_lambda_function" "copy_lambda" {
  filename         = "lambda.zip"
  function_name    = "copy-s3-file"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda.zip")
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.start.arn
}

resource "aws_s3_bucket_notification" "s3_notify_lambda" {
  bucket = aws_s3_bucket.start.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.copy_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
