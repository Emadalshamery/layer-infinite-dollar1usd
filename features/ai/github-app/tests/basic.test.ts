import request from 'supertest';
import app from '../src/index';

test('health check', async () => {
  const res = await request(app).get('/');
  expect(res.status).toBe(200);
  expect(res.text).toBe('OK');
});
