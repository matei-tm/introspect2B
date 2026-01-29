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

DRY_RUN="${DRY_RUN:-false}"

STACK_NAME="${STACK_NAME:-claim-status-api-apigw}"
TEMPLATE_FILE="${TEMPLATE_FILE:-apigw/api-gateway-template.yaml}"
# Allow both IAM capabilities by default; safe even if not needed
# shellcheck disable=SC2206
CAPABILITIES_ARR=( ${CAPABILITIES:-CAPABILITY_IAM CAPABILITY_NAMED_IAM} )

# Build parameter overrides
: "${SERVICE_ENDPOINT:?SERVICE_ENDPOINT env required}"
: "${ENVIRONMENT_NAME:?ENVIRONMENT_NAME env required}"
DEPLOYMENT_VERSION="${DEPLOYMENT_VERSION:-$(date +%s)}"

# Allow external PARAM_OVERRIDES (space-separated k=v pairs); otherwise construct array safely
if [[ -n "${PARAM_OVERRIDES:-}" ]]; then
  # shellcheck disable=SC2206
  PARAM_ARRAY=( ${PARAM_OVERRIDES} )
else
  PARAM_ARRAY=(
    "ServiceEndpoint=${SERVICE_ENDPOINT}"
    "EnvironmentName=${ENVIRONMENT_NAME}"
    "DeploymentVersion=${DEPLOYMENT_VERSION}"
  )
fi

echo "Deploying APIGW with SERVICE_ENDPOINT=${SERVICE_ENDPOINT:-N/A} ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-N/A} REGION=${AWS_REGION}"
echo "Stack name: ${STACK_NAME} | Template: ${TEMPLATE_FILE}"

on_error() {
  echo "Deployment failed. Fetching recent stack events (if any)..." >&2
  if [[ "${DRY_RUN}" != "true" ]]; then
    aws cloudformation describe-stack-events --stack-name "${STACK_NAME}" --region "${AWS_REGION}" --output table | head -n 200 || true
  fi
}
trap on_error ERR

stack_exists() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY_RUN] aws cloudformation describe-stacks --stack-name \"${STACK_NAME}\" --region \"${AWS_REGION}\"" >&2
    return 1
  fi
  aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    >/dev/null 2>&1
}

stack_status() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY_RUN] aws cloudformation describe-stacks --stack-name \"${STACK_NAME}\" --region \"${AWS_REGION}\" --query 'Stacks[0].StackStatus' --output text" >&2
    echo "CREATE_COMPLETE"
    return 0
  fi
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
      if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY_RUN] aws cloudformation delete-stack --stack-name \"${STACK_NAME}\" --region \"${AWS_REGION}\""
      else
        aws cloudformation delete-stack --stack-name "${STACK_NAME}" --region "${AWS_REGION}"
      fi
      echo "Waiting for stack deletion to complete..."
      if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY_RUN] aws cloudformation wait stack-delete-complete --stack-name \"${STACK_NAME}\" --region \"${AWS_REGION}\""
      else
        aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}" --region "${AWS_REGION}"
      fi
      ;;
    *)
      echo "Stack is in a deployable state; proceeding with update."
      ;;
  esac
else
  echo "Stack does not exist; will create it."
fi

echo "Starting CloudFormation deploy..."
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "[DRY_RUN] aws cloudformation validate-template --template-body file://${TEMPLATE_FILE}" 
  echo "[DRY_RUN] aws cloudformation deploy \\"
  echo "  --stack-name \"${STACK_NAME}\" \\"
  echo "  --template-file \"${TEMPLATE_FILE}\" \\"
  echo "  --parameter-overrides ${PARAM_ARRAY[*]} \\"
  echo "  --no-fail-on-empty-changeset \\"
  echo "  --capabilities ${CAPABILITIES_ARR[*]} \\"
  echo "  --region \"${AWS_REGION}\""
else
  aws cloudformation validate-template --template-body "file://${TEMPLATE_FILE}" 
  aws cloudformation deploy \
    --stack-name "${STACK_NAME}" \
    --template-file "${TEMPLATE_FILE}" \
    --parameter-overrides "${PARAM_ARRAY[@]}" \
    --no-fail-on-empty-changeset \
    --capabilities ${CAPABILITIES_ARR[@]} \
    --region "${AWS_REGION}"
fi

echo "Deploy complete."
