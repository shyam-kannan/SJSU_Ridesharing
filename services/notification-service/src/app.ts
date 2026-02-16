import express, { Application } from 'express';
import cors from 'cors';

const app: Application = express();
app.use(express.json());
app.use(cors());

// Health check
app.get('/health', (_req, res) => {
  res.json({
    status: 'success',
    message: 'Notification Service is running',
    service: 'notification-service',
    timestamp: new Date().toISOString(),
  });
});

// Generic send endpoint (stub)
app.post('/notifications/send', (req, res) => {
  const { user_id, type, title, message, data } = req.body;

  if (!user_id || !type || !title || !message) {
    res.status(400).json({
      status: 'error',
      message: 'user_id, type, title, and message are required',
    });
    return;
  }

  console.log(`[NOTIFICATION] type=${type} user=${user_id} title="${title}" message="${message}"`);
  if (data) console.log(`  data=${JSON.stringify(data)}`);

  res.json({
    status: 'success',
    message: 'Notification sent (stub)',
    data: { user_id, type, title },
  });
});

// Email notification (stub)
app.post('/notifications/email', (req, res) => {
  const { user_id, email, subject, message, data } = req.body;

  console.log(`[EMAIL STUB] to=${email} user=${user_id} subject="${subject}" message="${message}"`);
  if (data) console.log(`  data=${JSON.stringify(data)}`);

  res.json({
    status: 'success',
    message: 'Email notification queued (stub)',
    data: { user_id, email, subject },
  });
});

// Push notification (stub)
app.post('/notifications/push', (req, res) => {
  const { user_id, title, message, data } = req.body;

  console.log(`[PUSH STUB] user=${user_id} title="${title}" message="${message}"`);
  if (data) console.log(`  data=${JSON.stringify(data)}`);

  res.json({
    status: 'success',
    message: 'Push notification sent (stub)',
    data: { user_id, title },
  });
});

export default app;
