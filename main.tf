terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      
    }
  }
  cloud {
    organization = "jsanchezsv95"

    workspaces {
      name = "gh-actions-challenge7"
    }
  }
}
provider "aws" {
  region = "us-east-1"
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
  role = aws_iam_role.writeRole.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1604733000129",
            "Action": [
                "dynamodb:BatchWriteItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:dynamodb:us-east-1:072834578119:table/user"
        }
    ]
  })
}

resource "aws_iam_role_policy" "read_policy" {
  name = "lambda_read_policy"
  role = aws_iam_role.readRole.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1604732925387",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:dynamodb:us-east-1:072834578119:table/user"
        }
    ]
  })
}

resource "aws_iam_role" "writeRole" {
  name = "myWriteRole"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })

}

resource "aws_iam_role" "readRole" {
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
resource "aws_lambda_function" "writeLambda" {

  function_name = "writeLambda"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambdaf_write.key
  role          = aws_iam_role.writeRole.arn
  handler       = "writedb_lambda.handler"
  runtime       = "nodejs12.x"
}

resource "aws_lambda_function" "readLambda" {

  function_name = "readLambda"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambdaf_read.key
  role          = aws_iam_role.readRole.arn
  handler       = "readdb_lambda.handler"
  runtime       = "nodejs12.x"
}

resource "aws_api_gateway_rest_api" "apiLambda" {
  name = "APIgateway"

}

resource "aws_api_gateway_resource" "writeResource" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  parent_id   = aws_api_gateway_rest_api.apiLambda.root_resource_id
  path_part   = "writedb"

}

resource "aws_api_gateway_method" "writeMethod" {
  rest_api_id   = aws_api_gateway_rest_api.apiLambda.id
  resource_id   = aws_api_gateway_resource.writeResource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "readResource" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  parent_id   = aws_api_gateway_rest_api.apiLambda.root_resource_id
  path_part   = "readdb"

}

resource "aws_api_gateway_method" "readMethod" {
  rest_api_id   = aws_api_gateway_rest_api.apiLambda.id
  resource_id   = aws_api_gateway_resource.readResource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "writeInt" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  resource_id = aws_api_gateway_resource.writeResource.id
  http_method = aws_api_gateway_method.writeMethod.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.writeLambda.invoke_arn

}

resource "aws_api_gateway_integration" "readInt" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  resource_id = aws_api_gateway_resource.readResource.id
  http_method = aws_api_gateway_method.readMethod.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.readLambda.invoke_arn

}

resource "aws_api_gateway_deployment" "apideploy" {
  depends_on = [aws_api_gateway_integration.writeInt, aws_api_gateway_integration.readInt]

  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  stage_name  = "Prod"
}

resource "aws_lambda_permission" "writePermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.writeLambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/Prod/POST/writedb"

}

resource "aws_lambda_permission" "readPermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.readLambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/Prod/POST/readdb"

}