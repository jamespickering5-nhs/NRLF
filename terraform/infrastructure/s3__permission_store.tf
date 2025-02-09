resource "aws_s3_bucket" "authorization-store" {
  bucket        = "${local.prefix}--authorization-store"
  force_destroy = true

  tags = {
    Name        = "authorization store"
    Environment = "${local.prefix}"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "authorization-store" {
  bucket = aws_s3_bucket.authorization-store.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "authorization-store" {
  bucket = aws_s3_bucket.authorization-store.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "allow-authorizer-lambda-to-read" {
  bucket = aws_s3_bucket.authorization-store.id
  policy = data.aws_iam_policy_document.allow-authorizer-lambda-to-read.json
}

data "aws_iam_policy_document" "allow-authorizer-lambda-to-read" {
  statement {
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.assume_account}:role/${module.producer__authoriser_lambda.lambda_role_name}",
        "arn:aws:iam::${var.assume_account}:role/${module.consumer__authoriser_lambda.lambda_role_name}"
      ]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.authorization-store.arn,
      "${aws_s3_bucket.authorization-store.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "read-authorization-store-s3" {
  name        = "${local.prefix}--read-authorization-store-s3"
  description = "Read the authorization store S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.authorization-store.arn
        ]
      },
    ]
  })
}
