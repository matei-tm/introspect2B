# Introspect2B: GenAI-Powered Claim Status API

| Workflow | Status |
|---|---|
| 1. Lab Setup | [![1. Lab Setup](https://github.com/matei-tm/introspect2B/actions/workflows/G1.0.lab-setup.yml/badge.svg)](https://github.com/matei-tm/introspect2B/actions/workflows/G1.0.lab-setup.yml) |
| 2.1 Deploy Terraform Infrastructure | [![2.1 Deploy Terraform Infrastructure](https://github.com/matei-tm/introspect2B/actions/workflows/G2.terraform-deploy.yml/badge.svg)](https://github.com/matei-tm/introspect2B/actions/workflows/G2.terraform-deploy.yml) |
| 3. Auto-trigger CodePipeline | [![3. Auto-trigger CodePipeline](https://github.com/matei-tm/introspect2B/actions/workflows/G3.trigger-codepipeline.yml/badge.svg)](https://github.com/matei-tm/introspect2B/actions/workflows/G3.trigger-codepipeline.yml) |
| 4. Test and Collect Logs | [![4. Test and Collect Logs](https://github.com/matei-tm/introspect2B/actions/workflows/G4.test-and-logs.yml/badge.svg)](https://github.com/matei-tm/introspect2B/actions/workflows/G4.test-and-logs.yml) |
| documentation build and deployment | [![pages build and deployment](https://github.com/matei-tm/introspect2B/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/matei-tm/introspect2B/actions?query=workflow%3A%22pages+build+and+deployment%22) |

A production-ready cloud-native microservice demonstrating enterprise-grade architecture patterns for GenAI integration on AWS. Built with .NET 10, Amazon EKS, and Amazon Bedrock.

## 🎯 Overview

**Introspect2B** provides a complete example of integrating generative AI into insurance claim processing workflows. The API retrieves claim information from DynamoDB, fetches detailed notes from S3, and uses Amazon Bedrock (Nova Lite) to generate contextual summaries for different stakeholder perspectives.

### Key Features

✅ **RESTful API** — Claim retrieval and AI-powered summarization endpoints  
✅ **GenAI Integration** — Amazon Bedrock with Amazon Nova Lite for intelligent summaries  
✅ **Intelligent Autoscaling** — AI-workload-aware Lambda autoscaler with trend analysis  
✅ **Cloud-Native** — Kubernetes on Amazon EKS with high availability  
✅ **Security** — IRSA (IAM Roles for Service Accounts), least-privilege permissions  
✅ **Observability** — CloudWatch Container Insights and custom dashboards  
✅ **Infrastructure as Code** — Complete Terraform modules for AWS deployment  
✅ **CI/CD** — GitHub Actions workflows and AWS CodePipeline integration  

## 🚀 Quick Start

Deploy the complete system using GitHub Actions in 30 minutes:

1. **Fork this repository** to your GitHub account
2. **Configure GitHub Secrets** with your AWS credentials
3. **Run the Lab Setup workflow** (G1.0) from the Actions tab
4. **Monitor the deployment** through CodePipeline
5. **Test the API** using CloudWatch Logs Insights

**📖 Full Guide:** [Getting Started Documentation](https://matei-tm.github.io/introspect2B/getting-started)

## 🏗️ Architecture

The system implements a cloud-native microservices architecture on AWS:

- **API Gateway** — Regional endpoint with AWS_IAM authentication
- **Amazon EKS** — Kubernetes cluster with 2-10 pod autoscaling
- **Claim Status API** — .NET 10 microservice with Bedrock integration
- **Data Layer** — DynamoDB for claims, S3 for detailed notes
- **Intelligent Autoscaler** — Lambda function with AI-workload awareness
- **Observability** — CloudWatch Container Insights and custom dashboards

**📖 Learn More:** [System Architecture](https://matei-tm.github.io/introspect2B/architecture/overview) | [Intelligent Autoscaling](https://matei-tm.github.io/introspect2B/features/intelligent-autoscaling)

## 📡 API Endpoints

### Get Claim by ID
```bash
GET /api/claims/{id}
```

### Generate AI Summary
```bash
POST /api/claims/{id}/summarize
```

**📖 Complete API Documentation:** [API Reference](https://matei-tm.github.io/introspect2B/api-reference)

## 🛠️ Technology Stack

| Layer | Technology |
|-------|-----------|
| **API** | ASP.NET Core 10.0 (Minimal API) |
| **Container Orchestration** | Amazon EKS 1.31 |
| **AI/ML** | Amazon Bedrock (Nova Lite) |
| **Autoscaling** | AWS Lambda (Python 3.11) |
| **Data Storage** | DynamoDB, S3 |
| **API Gateway** | Amazon API Gateway (Regional) |
| **Infrastructure as Code** | Terraform 1.6+ |
| **CI/CD** | GitHub Actions, AWS CodePipeline |
| **Observability** | CloudWatch Container Insights |

## 📚 Documentation

Complete documentation is available at **[https://matei-tm.github.io/introspect2B/](https://matei-tm.github.io/introspect2B/)**

### Key Topics

- **[Getting Started](https://matei-tm.github.io/introspect2B/getting-started)** — Deploy in 30 minutes with GitHub Actions
- **[Architecture Overview](https://matei-tm.github.io/introspect2B/architecture/overview)** — System design and components
- **[Intelligent Autoscaling](https://matei-tm.github.io/introspect2B/features/intelligent-autoscaling)** — AI-workload-aware scaling system
- **[API Reference](https://matei-tm.github.io/introspect2B/api-reference)** — Complete endpoint documentation
- **[Deployment Guide](https://matei-tm.github.io/introspect2B/deployment/deployment-guide)** — Advanced deployment patterns

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

This project is for educational purposes as part of the [CTS - Architecting for Performance CNA Level 2 – Intermediate (GGM)](https://www.niit.com/) course.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests for improvements.

For questions, feedback, or support:
- 🐛 [Report an Issue](https://github.com/matei-tm/introspect2B/issues)
- 💬 [GitHub Discussions](https://github.com/matei-tm/introspect2B/discussions)
- 📖 [Full Documentation](https://matei-tm.github.io/introspect2B/)

---

**Built with ❤️ for cloud-native AI applications**