# Claim Status API Performance Tests

This folder hosts the k6 scenario executed from AWS CodeBuild. Tests read the target URL from the `BASE_URL` environment variable (wired to the CloudFormation parameter `PerformanceTestUrl`).

Run locally with:

```bash
BASE_URL=https://your-endpoint.example.com k6 run performance-test.js
```

Tune the scenario by editing the `options` stages or thresholds in `performance-test.js`.
