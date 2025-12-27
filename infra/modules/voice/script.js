import http from 'k6/http';
import { check,sleep } from 'k6';

export const options = {
  vus: 100,
  duration: '1m',
};

export default function () {
  const url = 'http://pastebin-app-lb-1355204136.us-east-1.elb.amazonaws.com/login'; // Example endpoint
  const payload = JSON.stringify({
    username: 'keval',
    password: 'keval'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  const res = http.post(url, payload, params);
  check(res, {
    'status is 200': (r) => r.status === 200,
  })
  sleep(1);
}