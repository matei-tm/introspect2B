# Terraform Platform Module

This module provisions the EKS cluster and platform services.

## Usage

1. Apply the core module first to create the VPC and shared resources.
2. Copy outputs from the core module into the platform inputs (VPC IDs and claim notes bucket ARN).

```bash
cd ../core
terraform init
terraform apply
terraform output -json > core-outputs.json

cd ../platform
terraform init
terraform apply
```
