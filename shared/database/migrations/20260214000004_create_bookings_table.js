/**
 * Migration: Create Bookings Table
 * Stores booking requests from riders for trips
 */

exports.up = (pgm) => {
  // Create ENUM type for booking status
  pgm.createType('booking_status', ['pending', 'confirmed', 'cancelled', 'completed']);

  // Create bookings table
  pgm.createTable('bookings', {
    booking_id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
      notNull: true,
    },
    trip_id: {
      type: 'uuid',
      notNull: true,
      references: 'trips(trip_id)',
      onDelete: 'CASCADE',
    },
    rider_id: {
      type: 'uuid',
      notNull: true,
      references: 'users(user_id)',
      onDelete: 'CASCADE',
    },
    status: {
      type: 'booking_status',
      notNull: true,
      default: 'pending',
    },
    seats_booked: {
      type: 'integer',
      notNull: true,
      default: 1,
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
  pgm.createIndex('bookings', 'trip_id');
  pgm.createIndex('bookings', 'rider_id');
  pgm.createIndex('bookings', 'status');

  // Create composite index for common queries
  pgm.createIndex('bookings', ['rider_id', 'status']);
  pgm.createIndex('bookings', ['trip_id', 'status']);

  // Create trigger to automatically update updated_at timestamp
  pgm.sql(`
    CREATE TRIGGER update_bookings_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  `);

  console.log('Bookings table created successfully');
};

exports.down = (pgm) => {
  pgm.dropTable('bookings', { cascade: true });
  pgm.dropType('booking_status');
};
