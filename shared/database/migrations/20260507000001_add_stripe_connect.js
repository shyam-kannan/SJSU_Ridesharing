/**
 * Migration: Add Stripe Connect account ID to users table
 * - stripe_connect_account_id: Stripe Express account ID for driver payouts
 */

exports.up = (pgm) => {
  pgm.addColumns('users', {
    stripe_connect_account_id: {
      type: 'varchar(255)',
      notNull: false,
    },
  });

  console.log('Added stripe_connect_account_id column to users table');
};

exports.down = (pgm) => {
  pgm.dropColumns('users', ['stripe_connect_account_id']);
};
