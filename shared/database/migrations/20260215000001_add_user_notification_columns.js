/**
 * Migration: Add notification columns to users table
 * - device_token: APNs/FCM push notification token
 * - email_notifications: whether to send email notifications
 * - push_notifications: whether to send push notifications
 */

exports.up = (pgm) => {
  pgm.addColumns('users', {
    device_token: {
      type: 'varchar(255)',
      notNull: false,
    },
    email_notifications: {
      type: 'boolean',
      notNull: true,
      default: true,
    },
    push_notifications: {
      type: 'boolean',
      notNull: true,
      default: true,
    },
  });

  console.log('Added notification columns to users table');
};

exports.down = (pgm) => {
  pgm.dropColumns('users', ['device_token', 'email_notifications', 'push_notifications']);
};
