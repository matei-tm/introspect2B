import http from 'k6/http';
import { check, sleep } from 'k6';

const baseUrl = __ENV.BASE_URL || 'https://introspect2b.matei-tm.eu';
const apiKey = __ENV.API_KEY || '';

export const options = {
  stages: [
    { duration: '1m', target: 10 },
    { duration: '3m', target: 30 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
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
  let postJson = null;
  try {
    postJson = JSON.parse(postRes.body);
  } catch (e) {
    postJson = null;
  }


  const hasNodeError = postJson &&
    JSON.stringify(postJson).toLowerCase().includes('node error');

  const hasSummaryNodes = postJson &&
    Object.prototype.hasOwnProperty.call(postJson, 'generatedAt') &&
    Object.prototype.hasOwnProperty.call(postJson, 'model');

  check(postRes, {
    'POST /summarize returns 200 with summary nodes': (r) => r.status === 200 && hasSummaryNodes,
    'POST returns valid JSON': () => postJson !== null,
    'POST response does not contain node error': () => !hasNodeError,
    'POST response time < 20000ms': (r) => r.timings.duration < 20000, // Bedrock can be slow
  });

  sleep(1);
}
