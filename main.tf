terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0"
    }
    
  }
}

provider "aws" {
  region = "us-east-1"
}
#configure backend
terraform {
  backend "s3" {
      bucket         = "my-terraform-bucket4533"
      key            = "test/terraform.tfstate"
      region         = "us-east-1"
      dynamodb_table = "bucket-state-dynamodb-table"
    }
}
#dynamoDB for the bucket
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "bucket-state-dynamodb-table"
  billing_mode = "PROVISIONED"
  read_capacity  = "20"
  write_capacity = "20"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

#Define DynamoDB
resource "aws_dynamodb_table" "user" {
  name           = "user"
  billing_mode   = "PROVISIONED"
  read_capacity  = "20"
  write_capacity = "20"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role_policy" "write_policy" {
  name = "lambda_write_policy"
  role = aws_iam_role.write_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Stmt1604733000129",
        "Action" : [
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:dynamodb:us-east-1:072834578119:table/user"
      }
    ]
  })
}

resource "aws_iam_role_policy" "read_policy" {
  name = "lambda_read_policy"
  role = aws_iam_role.read_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Stmt1604732925387",
        "Action" : [
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:dynamodb:us-east-1:072834578119:table/user"
      }
    ]
  })
}

resource "aws_iam_role" "write_role" {
  name = "myWriteRole"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

}

resource "aws_iam_role" "read_role" {
  name = "myReadRole"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

}
#s3 bucket
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "bucketlbd-34453432"
}

#Create lambdas function
resource "aws_lambda_function" "write_lambda" {

  function_name = "write_lambda"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambdaf_write.key
  role          = aws_iam_role.write_role.arn
  handler       = "writedb_lambda.handler"
  runtime       = "nodejs12.x"
}

resource "aws_lambda_function" "read_lambda" {

  function_name = "read_lambda"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambdaf_read.key
  role          = aws_iam_role.read_role.arn
  handler       = "readdb_lambda.handler"
  runtime       = "nodejs12.x"
}
#creation of the api
resource "aws_api_gateway_rest_api" "apigtw" {
  name = "APIgateway"

}
#creating the REST API
resource "aws_api_gateway_resource" "write_resource" {
  rest_api_id = aws_api_gateway_rest_api.apigtw.id
  parent_id   = aws_api_gateway_rest_api.apigtw.root_resource_id
  path_part   = "writedb"

}

resource "aws_api_gateway_method" "write_method" {
  rest_api_id   = aws_api_gateway_rest_api.apigtw.id
  resource_id   = aws_api_gateway_resource.write_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "read_resource" {
  rest_api_id = aws_api_gateway_rest_api.apigtw.id
  parent_id   = aws_api_gateway_rest_api.apigtw.root_resource_id
  path_part   = "readdb"

}

resource "aws_api_gateway_method" "read_method" {
  rest_api_id   = aws_api_gateway_rest_api.apigtw.id
  resource_id   = aws_api_gateway_resource.read_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "write_integration" {
  rest_api_id = aws_api_gateway_rest_api.apigtw.id
  resource_id = aws_api_gateway_resource.write_resource.id
  http_method = aws_api_gateway_method.write_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.write_lambda.invoke_arn

}

resource "aws_api_gateway_integration" "read_integration" {
  rest_api_id = aws_api_gateway_rest_api.apigtw.id
  resource_id = aws_api_gateway_resource.read_resource.id
  http_method = aws_api_gateway_method.read_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.read_lambda.invoke_arn

}

resource "aws_api_gateway_deployment" "apideploy" {
  depends_on = [aws_api_gateway_integration.write_integration, aws_api_gateway_integration.read_integration]

  rest_api_id = aws_api_gateway_rest_api.apigtw.id
  stage_name  = "Prod"
}

resource "aws_lambda_permission" "writePermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.write_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.apigtw.execution_arn}/Prod/POST/writedb"

}

resource "aws_lambda_permission" "readPermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.apigtw.execution_arn}/Prod/POST/readdb"

}