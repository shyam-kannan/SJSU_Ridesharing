/**
 * Migration: Create Trips Table
 * Stores trip information with geospatial data for origin and destination
 */

exports.up = (pgm) => {
  // Create ENUM type for trip status
  pgm.createType('trip_status', ['active', 'completed', 'cancelled']);

  // Create trips table
  pgm.createTable('trips', {
    trip_id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
      notNull: true,
    },
    driver_id: {
      type: 'uuid',
      notNull: true,
      references: 'users(user_id)',
      onDelete: 'CASCADE',
    },
    origin: {
      type: 'text',
      notNull: true,
    },
    destination: {
      type: 'text',
      notNull: true,
    },
    origin_point: {
      type: 'geography(POINT, 4326)',
      notNull: true,
    },
    destination_point: {
      type: 'geography(POINT, 4326)',
      notNull: true,
    },
    departure_time: {
      type: 'timestamp',
      notNull: true,
    },
    seats_available: {
      type: 'integer',
      notNull: true,
    },
    recurrence: {
      type: 'varchar(100)',
    },
    status: {
      type: 'trip_status',
      notNull: true,
      default: 'active',
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
  pgm.createIndex('trips', 'driver_id');
  pgm.createIndex('trips', 'status');
  pgm.createIndex('trips', 'departure_time');

  // Create spatial indexes for geospatial queries (GiST indexes)
  pgm.sql('CREATE INDEX idx_trips_origin_point ON trips USING GIST(origin_point);');
  pgm.sql('CREATE INDEX idx_trips_destination_point ON trips USING GIST(destination_point);');

  // Create trigger to automatically update updated_at timestamp
  pgm.sql(`
    CREATE TRIGGER update_trips_updated_at
    BEFORE UPDATE ON trips
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  `);

  console.log('Trips table created successfully with PostGIS support');
};

exports.down = (pgm) => {
  pgm.dropTable('trips', { cascade: true });
  pgm.dropType('trip_status');
};
