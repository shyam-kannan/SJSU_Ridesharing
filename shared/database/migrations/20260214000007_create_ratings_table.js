/**
 * Migration: Create Ratings Table
 * Stores ratings between users after completed trips
 */

exports.up = (pgm) => {
  // Create ratings table
  pgm.createTable('ratings', {
    rating_id: {
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
    rater_id: {
      type: 'uuid',
      notNull: true,
      references: 'users(user_id)',
      onDelete: 'CASCADE',
    },
    ratee_id: {
      type: 'uuid',
      notNull: true,
      references: 'users(user_id)',
      onDelete: 'CASCADE',
    },
    score: {
      type: 'integer',
      notNull: true,
    },
    comment: {
      type: 'text',
    },
    created_at: {
      type: 'timestamp',
      notNull: true,
      default: pgm.func('current_timestamp'),
    },
  });

  // Create indexes for better query performance
  pgm.createIndex('ratings', 'booking_id');
  pgm.createIndex('ratings', 'rater_id');
  pgm.createIndex('ratings', 'ratee_id');

  // Add constraint to ensure score is between 1 and 5
  pgm.sql(`
    ALTER TABLE ratings
    ADD CONSTRAINT check_rating_score_range
    CHECK (score >= 1 AND score <= 5);
  `);

  // Prevent duplicate ratings (same rater for same booking)
  pgm.addConstraint('ratings', 'unique_rater_per_booking', {
    unique: ['booking_id', 'rater_id'],
  });

  console.log('Ratings table created successfully with score validation');
};

exports.down = (pgm) => {
  pgm.dropTable('ratings', { cascade: true });
};
