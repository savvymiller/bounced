# tapid-main — single-table design. See docs/DATA_MODEL.md for the full
# key design, item shapes, and access patterns this schema serves.
#
# The defining property of this table: there is no column for PII (no
# name, DOB, portrait, or document ID). Adding one requires a new ADR
# per docs/adr/0003-zero-retention.md, enforced in CI by PR-24.

resource "aws_dynamodb_table" "main" {
  name         = "${var.project}-main-${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # ADR-0006: traffic is ~28x peak/average; on-demand tracks usage, not peak.

  hash_key  = "PK"
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  # GSI key attributes. These are separate physical attributes from
  # PK/SK (DynamoDB requires one value per attribute name per item), set
  # only on the item types that need that access pattern — see
  # DATA_MODEL.md's "Global secondary indexes" table for which items
  # populate which GSI.
  attribute {
    name = "GSI1PK" # ORG#{orgId}      — chain-wide activity across venues
    type = "S"
  }
  attribute {
    name = "GSI1SK" # EVT#{timestamp}
    type = "S"
  }
  attribute {
    name = "GSI2PK" # DEVICE#{deviceId} — per-device audit / fraud investigation
    type = "S"
  }
  attribute {
    name = "GSI2SK" # EVT#{timestamp}
    type = "S"
  }
  attribute {
    name = "GSI3PK" # STAFF#{staffId}   — "what did this employee work?"
    type = "S"
  }
  attribute {
    name = "GSI3SK" # SHIFT#{startIso}
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI2"
    hash_key        = "GSI2PK"
    range_key       = "GSI2SK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI3"
    hash_key        = "GSI3PK"
    range_key       = "GSI3SK"
    projection_type = "ALL"
  }

  # 90-day operational hot window (DATA_MODEL.md "Retention and
  # lifecycle"). S3/Athena is the multi-year archive — see PR-26.
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Feeds the rollup consumer (PR-25) and, later, EventBridge fan-out.
  # NEW_AND_OLD_IMAGES rather than NEW_IMAGE: Device/Shift items are
  # updated in place (status, endedAt), and a future consumer diffing
  # those needs the prior value — cheap to keep both now rather than
  # re-provision later.
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  deletion_protection_enabled = var.deletion_protection_enabled

  tags = {
    DataClassification = "zero-pii" # ADR-0003
  }
}
