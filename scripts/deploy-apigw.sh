#!/usr/bin/env bash
set -Eeuo pipefail

# Robust CloudFormation deploy for API Gateway template.
# - Deletes the stack first if it's stuck in ROLLBACK_* or CREATE_FAILED states
# - Falls back to clean create/update via `aws cloudformation deploy`

: "${AWS_REGION:=${AWS_DEFAULT_REGION:-}}"
if [[ -z "${AWS_REGION}" ]]; then
  echo "AWS_REGION or AWS_DEFAULT_REGION must be set" >&2
  exit 1
fi

STACK_NAME="${STACK_NAME:-claim-status-api-apigw}"
TEMPLATE_FILE="${TEMPLATE_FILE:-apigw/api-gateway-template.yaml}"
CAPABILITIES="${CAPABILITIES:-CAPABILITY_IAM}"

# Build parameter overrides if not provided explicitly
if [[ -z "${PARAM_OVERRIDES:-}" ]]; then
  : "${SERVICE_ENDPOINT:?SERVICE_ENDPOINT env required}"
  : "${ENVIRONMENT_NAME:?ENVIRONMENT_NAME env required}"
  DEPLOYMENT_VERSION="${DEPLOYMENT_VERSION:-$(date +%s)}"
  # Note: leave unquoted expansion at deploy time to allow splitting into k=v pairs
  PARAM_OVERRIDES="ServiceEndpoint=${SERVICE_ENDPOINT} EnvironmentName=${ENVIRONMENT_NAME} DeploymentVersion=${DEPLOYMENT_VERSION}"
fi

echo "Deploying APIGW with SERVICE_ENDPOINT=${SERVICE_ENDPOINT:-N/A} ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-N/A} REGION=${AWS_REGION}"
echo "Stack name: ${STACK_NAME} | Template: ${TEMPLATE_FILE}"

stack_exists() {
  aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    >/dev/null 2>&1
}

stack_status() {
  aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || true
}

if stack_exists; then
  STATUS="$(stack_status)"
  echo "Existing stack status: ${STATUS}"
  case "${STATUS}" in
    ROLLBACK_COMPLETE|ROLLBACK_FAILED|CREATE_FAILED|UPDATE_ROLLBACK_COMPLETE|UPDATE_ROLLBACK_FAILED)
      echo "Stack is in a failed/rollback state (${STATUS}). Deleting before redeploy..."
      aws cloudformation delete-stack --stack-name "${STACK_NAME}" --region "${AWS_REGION}"
      echo "Waiting for stack deletion to complete..."
      aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}" --region "${AWS_REGION}"
      ;;
    *)
      echo "Stack is in a deployable state; proceeding with update."
      ;;
  esac
else
  echo "Stack does not exist; will create it."
fi

echo "Starting CloudFormation deploy..."
aws cloudformation deploy \
  --stack-name "${STACK_NAME}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameter-overrides "${PARAM_OVERRIDES}" \
  --no-fail-on-empty-changeset \
  --capabilities "${CAPABILITIES}" \
  --region "${AWS_REGION}"

echo "Deploy complete."
