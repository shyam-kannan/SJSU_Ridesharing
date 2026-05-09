import http from 'k6/http';
import { check } from 'k6';
import { BASE_URL } from './config.js';

/**
 * Register + login a user, return { token, userId }.
 * Call once in setup() and pass the result to default().
 */
export function authenticate(role = 'Rider') {
  const ts = Date.now();
  const email = `load-${role.toLowerCase()}-${ts}-${Math.random().toString(36).slice(2)}@sjsu.edu`;
  const payload = JSON.stringify({
    name: `Load ${role} ${ts}`,
    email,
    password: 'LoadTest123!',
    role,
  });
  const headers = { 'Content-Type': 'application/json' };

  const res = http.post(`${BASE_URL}/api/auth/register`, payload, { headers });
  check(res, { 'register 200/201': (r) => r.status === 200 || r.status === 201 });

  const body = res.json();
  return {
    token: body?.data?.accessToken,
    userId: body?.data?.user?.user_id,
    email,
  };
}

export function authHeaders(token) {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}
