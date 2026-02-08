import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL || 'https://example.com';
const apiKey = __ENV.API_KEY || '';

export const options = {
  stages: [
    { duration: '1m', target: 10 },
    { duration: '3m', target: 30 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    checks: ['rate>0.99'],
  },
};

export default function () {
  const headers = apiKey ? { 'x-api-key': apiKey } : {};
  
  // Test GET /api/claims/{claimId}
  const getRes = http.get(`${baseUrl}/api/claims/CLAIM-001`, { headers });
  check(getRes, {
    'GET status is 200': (r) => r.status === 200,
    'GET response time < 400ms': (r) => r.timings.duration < 400,
    'GET has claim data': (r) => r.body.includes('CLAIM-001'),
  });

  sleep(1);

  // Test POST /api/claims/{claimId}/summarize
  const postHeaders = Object.assign({}, headers, { 'Content-Type': 'application/json' });
  const postRes = http.post(
    `${baseUrl}/api/claims/CLAIM-001/summarize`,
    JSON.stringify({ notesOverride: 'Performance test override' }),
    { headers: postHeaders }
  );
  check(postRes, {
    'POST status is 200': (r) => r.status === 200,
    'POST response time < 3000ms': (r) => r.timings.duration < 3000,
    'POST has summary': (r) => r.body.includes('summary') || r.body.includes('Summary'),
  });

  sleep(1);
}
