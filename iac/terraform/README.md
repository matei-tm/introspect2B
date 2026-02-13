# Terraform

The Terraform configuration is split into two modules:

- core: networking and shared resources
- platform: EKS and platform services

Apply core first, then apply platform using outputs from core.
