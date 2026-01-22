#!/bin/bash
set -e

NAMESPACE="dapr-demo"
AWS_REGION="${AWS_REGION:-us-east-1}"
DYNAMODB_TABLE="dapr-state-table"
S3_BUCKET="claim-notes-$(aws sts get-caller-identity --query Account --output text)"

echo "📝 Initializing sample claim data"
echo "=================================="
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "S3 Bucket: $S3_BUCKET"
echo "AWS Region: $AWS_REGION"
echo ""

# Sample claim data
read -r -d '' CLAIM_JSON << 'EOF' || true
{
  "id": {"S": "CLAIM-001"},
  "status": {"S": "Under Review"},
  "claimType": {"S": "Property"},
  "submissionDate": {"S": "2024-01-15T10:30:00Z"},
  "claimantName": {"S": "John Doe"},
  "amount": {"S": "25000.00"},
  "notesKey": {"S": "claims/CLAIM-001/notes.txt"}
}
EOF

# Sample claim notes
read -r -d '' CLAIM_NOTES << 'EOF' || true
CLAIM #CLAIM-001 - PROPERTY DAMAGE ASSESSMENT
Date of Loss: January 15, 2024
Reported Date: January 16, 2024
Claimant: John Doe
Address: 123 Main Street, Springfield, IL 62701

INCIDENT DESCRIPTION:
Customer reported significant water damage to kitchen and dining room areas after a pipe burst in the main bathroom. The burst occurred on January 15, 2024, at approximately 2:30 PM. Customer was home and discovered water flowing through ceiling into kitchen below.

DAMAGE ASSESSMENT:
- Kitchen: Extensive water damage to laminate flooring, cabinet damage, appliance damage (dishwasher, refrigerator)
- Dining Room: Hardwood floor damage, some furniture damage
- Personal Items: Several boxes of stored items in basement affected
- Structural: No structural damage observed, but drywall requires replacement
- Electrical: HVAC system affected, requires inspection

PRELIMINARY ESTIMATE: $25,000
- Flooring replacement: $8,000
- Cabinet and countertop: $7,000
- Appliances: $5,000
- Drywall and repairs: $3,500
- Misc items and labor: $1,500

CLAIM HISTORY:
- No previous claims on this policy
- Policy active since: January 2019
- Coverage: Homeowners Insurance with water damage coverage
- Deductible: $1,000

NEXT STEPS:
- Schedule full property inspection
- Obtain detailed estimates from contractors
- Assess policy coverage limits
- Review deductible application
- Provide initial estimate to customer

NOTES:
Customer is cooperative and has documented photos of damage. Policy appears to be in good standing with no red flags. Recommend approval pending final inspection and estimate verification.

Inspector: Sarah Johnson, License #IL-2024-1234
Date: January 23, 2024
EOF

# Put item in DynamoDB
echo "💾 Adding claim to DynamoDB..."
aws dynamodb put-item \
  --table-name $DYNAMODB_TABLE \
  --item "$CLAIM_JSON" \
  --region $AWS_REGION

echo "✅ Claim added to DynamoDB"

# Create S3 bucket if it doesn't exist
echo "🪣 Checking S3 bucket..."
if ! aws s3 ls "s3://$S3_BUCKET" --region $AWS_REGION 2>/dev/null; then
  echo "📦 Creating S3 bucket: $S3_BUCKET"
  aws s3 mb "s3://$S3_BUCKET" --region $AWS_REGION
  
  # Block public access
  aws s3api put-public-access-block \
    --bucket $S3_BUCKET \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region $AWS_REGION
else
  echo "✅ S3 bucket already exists"
fi

# Upload claim notes
echo "📄 Uploading claim notes to S3..."
echo "$CLAIM_NOTES" | aws s3 cp - \
  "s3://$S3_BUCKET/claims/CLAIM-001/notes.txt" \
  --region $AWS_REGION

echo "✅ Claim notes uploaded to S3"

echo ""
echo "✅ Sample data initialized successfully!"
echo ""
echo "Test the API:"
echo "  curl http://localhost:8080/api/claims/CLAIM-001"
echo "  curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize"
