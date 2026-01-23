#!/usr/bin/env bash
set -euo pipefail

# Initialize sample data: uploads a notes file to S3 and inserts a claim item in DynamoDB
# Uses environment variables when provided, with sensible defaults.

AWS_REGION=${AWS_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TABLE_NAME=${AWS__DynamoDb__TableName:-${AWS_DYNAMODB_TABLE:-claims}}
BUCKET_NAME=${AWS__S3__BucketName:-claim-notes-${ACCOUNT_ID}}

CLAIM_ID=${CLAIM_ID:-CLAIM-001}
NOTES_KEY=${NOTES_KEY:-notes/${CLAIM_ID}.json}

REPO_ROOT=$(cd "$(dirname "$0")"/.. && pwd)
NOTES_SOURCE_FILE="${REPO_ROOT}/mocks/notes.json"

echo "Region:        ${AWS_REGION}"
echo "Account ID:    ${ACCOUNT_ID}"
echo "Table Name:    ${TABLE_NAME}"
echo "Bucket Name:   ${BUCKET_NAME}"
echo "Claim ID:      ${CLAIM_ID}"
echo "Notes Key:     ${NOTES_KEY}"

# Upload notes to S3
if [[ -f "${NOTES_SOURCE_FILE}" ]]; then
  echo "Uploading notes to s3://${BUCKET_NAME}/${NOTES_KEY}"
  aws s3 cp "${NOTES_SOURCE_FILE}" "s3://${BUCKET_NAME}/${NOTES_KEY}" --region "${AWS_REGION}"
else
  echo "Notes file not found at ${NOTES_SOURCE_FILE}. Creating a placeholder."
  echo '{"notes":"Sample claim notes for initialization."}' | aws s3 cp - "s3://${BUCKET_NAME}/${NOTES_KEY}" --region "${AWS_REGION}"
fi

# Determine table hash key attribute name
HASH_KEY=$(aws dynamodb describe-table \
  --table-name "${TABLE_NAME}" \
  --region "${AWS_REGION}" \
  --query 'Table.KeySchema[?KeyType==`HASH`].AttributeName | [0]' \
  --output text 2>/dev/null || echo "")

if [[ -z "${HASH_KEY}" || "${HASH_KEY}" == "None" ]]; then
  HASH_KEY="key"
fi

echo "Using hash key attribute: ${HASH_KEY}"

# Create DynamoDB item (include both primary key and 'id' for app reads)
echo "Inserting item into DynamoDB table ${TABLE_NAME}"
aws dynamodb put-item \
  --table-name "${TABLE_NAME}" \
  --region "${AWS_REGION}" \
  --item "{\
    \"${HASH_KEY}\":   {\"S\": \"${CLAIM_ID}\"},\
    \"id\":            {\"S\": \"${CLAIM_ID}\"},\
    \"status\":        {\"S\": \"Submitted\"},\
    \"claimType\":     {\"S\": \"Home\"},\
    \"submissionDate\":{\"S\": \"2024-11-15T10:30:00Z\"},\
    \"claimantName\":  {\"S\": \"Jane Doe\"},\
    \"amount\":        {\"S\": \"25000.00\"},\
    \"notesKey\":      {\"S\": \"${NOTES_KEY}\"}\
  }"

echo "✅ Sample data initialized: ${CLAIM_ID}"
