/**
 * Migration: Create Quotes Table
 * Stores pricing quotes for bookings with max_price (never increases guarantee)
 */

exports.up = (pgm) => {
  // Create quotes table
  pgm.createTable('quotes', {
    quote_id: {
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
      unique: true, // One quote per booking
    },
    max_price: {
      type: 'decimal(10,2)',
      notNull: true,
    },
    final_price: {
      type: 'decimal(10,2)',
    },
    created_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp'),
    },
  });

  // Create index for better query performance
  pgm.createIndex('quotes', 'booking_id');

  // Add constraint to ensure final_price never exceeds max_price
  pgm.sql(`
    ALTER TABLE quotes
    ADD CONSTRAINT check_final_price_not_exceeds_max
    CHECK (final_price IS NULL OR final_price <= max_price);
  `);

  console.log('Quotes table created successfully with price guarantee constraint');
};

exports.down = (pgm) => {
  pgm.dropTable('quotes', { cascade: true });
};
