provider "aws" {
  region = var.aws_region # Use a variable for the region
}

variable "aws_region" {
  type        = string
  default = "us-east-1"
  description = "The AWS region to deploy the resources"
}

variable "email_address" {
  type        = string
  description = "Email address for sns topic subscription"
}

# Create S3 buckets
resource "aws_s3_bucket" "source_bucket" {
  bucket = "image-source-bucketv1"
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = "image-destination-bucketv1"
}

# Create SNS topic
resource "aws_sns_topic" "image_resize_topic" {
  name = "image-resize-topic"
}

# Create SNS topic subscription
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.image_resize_topic.arn
  protocol  = "email"
  endpoint  = var.email_address  # Email address provided as a variable
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function_payload.zip" # Specify the output path for the zip file

  source {
    content  = file("${path.module}/lambda_function.py") # Specify the path to your Python file
    filename = "lambda_function.py"                      # Specify the filename within the zip file
  }
}

# Create Lambda function
resource "aws_lambda_function" "image_resize_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "image-resize-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  layers        = [format("arn:aws:lambda:%s:770693421928:layer:Klayers-p39-pillow:1", var.aws_region)]

  environment {
    variables = {
      DESTINATION_BUCKET = aws_s3_bucket.destination_bucket.id
      SOURCE_BUCKET      = aws_s3_bucket.source_bucket.id
      SNS_TOPIC_ARN      = aws_sns_topic.image_resize_topic.arn
    }
  }

  # # Trigger Lambda when an object is uploaded to the source bucket
  # event_source_token = aws_s3_bucket_notification.lambda_trigger.arn
}

# Create Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}


# Attach policy to Lambda role granting necessary permissions
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sns_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Attach AWSLambdaBasicExecutionRole policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_get_layer_version_policy" {
  name        = "lambda-get-layer-version-policy"
  description = "Allows lambda:GetLayerVersion action"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "lambda:GetLayerVersion",
      Resource = "*",
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_get_layer_version_attachment" {
  name       = "lambda-get-layer-version-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.lambda_get_layer_version_policy.arn
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_resize_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_resize_lambda.arn
    events              = ["s3:ObjectCreated:*"]
   
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
