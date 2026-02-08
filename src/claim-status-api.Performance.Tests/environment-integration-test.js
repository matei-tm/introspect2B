import http from 'k6/http';
import { check, sleep, group } from 'k6';

const baseUrl = __ENV.BASE_URL || 'https://example.com';
const apiKey = __ENV.API_KEY || '';

// Minimal load for integration testing - single virtual user
export const options = {
  vus: 1,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate<0.05'], // Less than 5% failures
    http_req_duration: ['p(95)<5000'], // 95% of requests under 5s
    checks: ['rate>0.95'], // 95% of checks pass
  },
};

export default function () {
  const headers = apiKey ? { 'x-api-key': apiKey } : {};

  group('Health Check', () => {
    const healthRes = http.get(`${baseUrl}/health`, { headers });
    check(healthRes, {
      'Health endpoint is reachable': (r) => r.status === 200,
      'Health response time < 1s': (r) => r.timings.duration < 1000,
    });
  });

  sleep(1);

  group('GET Claims Endpoint', () => {
    const getRes = http.get(`${baseUrl}/api/claims/CLAIM-001`, { headers });
    check(getRes, {
      'GET /api/claims returns 200': (r) => r.status === 200,
      'GET returns valid JSON': (r) => {
        try {
          JSON.parse(r.body);
          return true;
        } catch (e) {
          return false;
        }
      },
      'GET response contains claim ID': (r) => r.body.includes('CLAIM-001'),
      'GET response time < 2s': (r) => r.timings.duration < 2000,
    });
  });

  sleep(1);

  group('POST Summarize Endpoint', () => {
    const postHeaders = Object.assign({}, headers, { 'Content-Type': 'application/json' });
    const payload = JSON.stringify({ notesOverride: 'Integration test' });
    
    const postRes = http.post(
      `${baseUrl}/api/claims/CLAIM-001/summarize`,
      payload,
      { headers: postHeaders }
    );
    
    check(postRes, {
      'POST /summarize returns 200': (r) => r.status === 200,
      'POST returns valid JSON': (r) => {
        try {
          JSON.parse(r.body);
          return true;
        } catch (e) {
          return false;
        }
      },
      'POST response contains summary': (r) => r.body.includes('summary') || r.body.includes('Summary'),
      'POST response time < 5s': (r) => r.timings.duration < 5000, // Bedrock can be slow
    });
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
