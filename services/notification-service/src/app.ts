import express from 'express';
import cors from 'cors';

const app = express();
app.use(express.json());
app.use(cors());

app.get('/health', (req, res) => {
  res.json({ status: 'success', message: 'Notification Service is running' });
});

/**
 * Send email notification (STUB)
 * TODO: Integrate with SendGrid, AWS SES, or similar
 */
app.post('/notifications/email', (req, res) => {
  const { user_id, email, subject, message, data } = req.body;

  console.log('📧 EMAIL NOTIFICATION (STUB):');
  console.log(`  To: ${email} (User: ${user_id})`);
  console.log(`  Subject: ${subject}`);
  console.log(`  Message: ${message}`);
  console.log(`  Data: ${JSON.stringify(data)}`);

  res.json({
    status: 'success',
    message: 'Email notification queued (stub)',
    data: { user_id, email, subject },
  });
});

/**
 * Send push notification (STUB)
 * TODO: Integrate with Firebase Cloud Messaging (FCM)
 */
app.post('/notifications/push', (req, res) => {
  const { user_id, title, message, data } = req.body;

  console.log('🔔 PUSH NOTIFICATION (STUB):');
  console.log(`  User: ${user_id}`);
  console.log(`  Title: ${title}`);
  console.log(`  Message: ${message}`);
  console.log(`  Data: ${JSON.stringify(data)}`);

  res.json({
    status: 'success',
    message: 'Push notification sent (stub)',
    data: { user_id, title },
  });
});

const PORT = process.env.NOTIFICATION_SERVICE_PORT || 3006;
app.listen(PORT, () => {
  console.log(`🔔 Notification Service running on port ${PORT} (STUB mode)`);
});

export default app;
