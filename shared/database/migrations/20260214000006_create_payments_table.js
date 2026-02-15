/**
 * Migration: Create Payments Table
 * Stores payment transactions with Stripe integration
 */

exports.up = (pgm) => {
  // Create ENUM type for payment status
  pgm.createType('payment_status', ['pending', 'captured', 'refunded', 'failed']);

  // Create payments table
  pgm.createTable('payments', {
    payment_id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
      notNull: true,
    },
    booking_id: {
      type: 'uuid',
      notNull: true,
      references: 'bookings(booking_id)',
      onDelete: 'CASCADE',
    },
    stripe_payment_intent_id: {
      type: 'varchar(255)',
      unique: true,
    },
    amount: {
      type: 'decimal(10,2)',
      notNull: true,
    },
    status: {
      type: 'payment_status',
      notNull: true,
      default: 'pending',
    },
    created_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp'),
    },
    updated_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp'),
    },
  });

  // Create indexes for better query performance
  pgm.createIndex('payments', 'booking_id');
  pgm.createIndex('payments', 'stripe_payment_intent_id');
  pgm.createIndex('payments', 'status');

  // Create trigger to automatically update updated_at timestamp
  pgm.sql(`
    CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  `);

  console.log('Payments table created successfully');
};

exports.down = (pgm) => {
  pgm.dropTable('payments', { cascade: true });
  pgm.dropType('payment_status');
};
