#zip lambdas function
data "archive_file" "lambdaf_writedb" {
  type = "zip"

  source_file  = "./lambdas/writedb_lambda.js"
  output_path = "./lambdas/lambdawritedb.zip"
}

data "archive_file" "lambdaf_readdb" {
  type = "zip"

  source_file  = "./lambdas/readdb_lambda.js"
  output_path = "./lambdas/lambdareaddb.zip"
}

resource "aws_s3_object" "lambdaf_read" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "lambdareaddb.zip"
  source = data.archive_file.lambdaf_readdb.output_path
}

resource "aws_s3_object" "lambdaf_write" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "lambdawritedb.zip"
  source = data.archive_file.lambdaf_writedb.output_path
}