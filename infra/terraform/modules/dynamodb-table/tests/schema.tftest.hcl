# Asserts the table's key schema matches docs/DATA_MODEL.md. Runs fully
# offline via mock_provider (Terraform >= 1.7) — no AWS credentials, no
# real API calls, safe to run in CI on every PR.
#
#   terraform test
#
# This is the "terraform plan check asserting key schema in CI" called
# for by PR-04 in docs/DELIVERY_PLAN.md.

mock_provider "aws" {}

variables {
  project     = "tapid"
  environment = "test"
}

run "primary_key_matches_data_model" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.main.hash_key == "PK"
    error_message = "Table hash key must be PK (docs/DATA_MODEL.md)"
  }

  assert {
    condition     = aws_dynamodb_table.main.range_key == "SK"
    error_message = "Table range key must be SK (docs/DATA_MODEL.md)"
  }

  assert {
    condition     = aws_dynamodb_table.main.billing_mode == "PAY_PER_REQUEST"
    error_message = "Billing mode must be on-demand per ADR-0006"
  }
}

run "ttl_and_streams_enabled" {
  command = plan

  assert {
    condition     = one(aws_dynamodb_table.main.ttl).attribute_name == "ttl"
    error_message = "TTL attribute must be named 'ttl' (DATA_MODEL.md VerificationEvent.ttl)"
  }

  assert {
    condition     = one(aws_dynamodb_table.main.ttl).enabled == true
    error_message = "TTL must be enabled — DynamoDB is a 90-day operational window, not the archive"
  }

  assert {
    condition     = aws_dynamodb_table.main.stream_enabled == true
    error_message = "Streams must be enabled to feed the rollup consumer (PR-25)"
  }
}

run "exactly_three_gsis_with_data_model_keys" {
  # apply, not plan: on-demand billing leaves read/write capacity unknown
  # on the GSI objects at plan time, which makes the whole
  # global_secondary_index set unknown too. apply against the mock
  # provider resolves it without touching real AWS.
  command = apply

  assert {
    condition     = length(aws_dynamodb_table.main.global_secondary_index) == 3
    error_message = "DATA_MODEL.md specifies exactly three GSIs for v1 — see its note on holding the line at three"
  }

  assert {
    condition = contains(
      [for g in aws_dynamodb_table.main.global_secondary_index : "${g.name}:${g.hash_key}:${g.range_key}"],
      "GSI1:GSI1PK:GSI1SK"
    )
    error_message = "GSI1 must be keyed GSI1PK/GSI1SK (logical ORG#{orgId} / EVT#{timestamp})"
  }

  assert {
    condition = contains(
      [for g in aws_dynamodb_table.main.global_secondary_index : "${g.name}:${g.hash_key}:${g.range_key}"],
      "GSI2:GSI2PK:GSI2SK"
    )
    error_message = "GSI2 must be keyed GSI2PK/GSI2SK (logical DEVICE#{deviceId} / EVT#{timestamp})"
  }

  assert {
    condition = contains(
      [for g in aws_dynamodb_table.main.global_secondary_index : "${g.name}:${g.hash_key}:${g.range_key}"],
      "GSI3:GSI3PK:GSI3SK"
    )
    error_message = "GSI3 must be keyed GSI3PK/GSI3SK (logical STAFF#{staffId} / SHIFT#{startIso})"
  }
}

run "deletion_protection_defaults_safe" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.main.deletion_protection_enabled == true
    error_message = "deletion_protection_enabled must default to true — dev stacks opt out explicitly, prod/staging never do"
  }
}
