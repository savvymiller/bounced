output "api_endpoint" {
  description = "Base invoke URL, e.g. https://xxxx.execute-api.us-east-1.amazonaws.com"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "function_name" {
  value = aws_lambda_function.api.function_name
}
