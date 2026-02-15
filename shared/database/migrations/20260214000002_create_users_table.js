/**
 * Migration: Create Users Table
 * Stores user accounts with authentication, SJSU verification, and driver information
 */

exports.up = (pgm) => {
  // Create ENUM types for user
  pgm.createType('user_sjsu_status', ['pending', 'verified', 'rejected']);
  pgm.createType('user_role', ['Driver', 'Rider']);

  // Create users table
  pgm.createTable('users', {
    user_id: {
      type: 'uuid',
      primaryKey: true,
      default: pgm.func('gen_random_uuid()'),
      notNull: true,
    },
    name: {
      type: 'varchar(255)',
      notNull: true,
    },
    email: {
      type: 'varchar(255)',
      notNull: true,
      unique: true,
    },
    password_hash: {
      type: 'varchar(255)',
      notNull: true,
    },
    sjsu_id_status: {
      type: 'user_sjsu_status',
      notNull: true,
      default: 'pending',
    },
    sjsu_id_image_path: {
      type: 'varchar(500)',
    },
    role: {
      type: 'user_role',
      notNull: true,
    },
    rating: {
      type: 'decimal(3,2)',
      default: 0.0,
    },
    vehicle_info: {
      type: 'text',
    },
    seats_available: {
      type: 'integer',
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
  pgm.createIndex('users', 'email');
  pgm.createIndex('users', 'sjsu_id_status');
  pgm.createIndex('users', 'role');

  // Create trigger to automatically update updated_at timestamp
  pgm.sql(`
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = current_timestamp;
      RETURN NEW;
    END;
    $$ language 'plpgsql';
  `);

  pgm.sql(`
    CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  `);

  console.log('Users table created successfully');
};

exports.down = (pgm) => {
  pgm.dropTable('users', { cascade: true });
  pgm.dropType('user_role');
  pgm.dropType('user_sjsu_status');
  pgm.sql('DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;');
};
