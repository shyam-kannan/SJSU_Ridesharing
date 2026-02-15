const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const { faker } = require('@faker-js/faker');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// SJSU Campus coordinates: 37.3352° N, 122.8811° W
const SJSU_LAT = 37.3352;
const SJSU_LNG = -122.8811;

// Popular destinations from SJSU
const DESTINATIONS = [
  { name: 'San Francisco Downtown', lat: 37.7749, lng: -122.4194 },
  { name: 'Oakland', lat: 37.8044, lng: -122.2712 },
  { name: 'Palo Alto', lat: 37.4419, lng: -122.1430 },
  { name: 'Santa Clara', lat: 37.3541, lng: -121.9552 },
  { name: 'Milpitas', lat: 37.4323, lng: -121.8995 },
  { name: 'Fremont', lat: 37.5485, lng: -121.9886 },
  { name: 'Mountain View', lat: 37.3861, lng: -122.0839 },
  { name: 'Sunnyvale', lat: 37.3688, lng: -122.0363 },
];

function randomNearby(centerLat, centerLng, radiusKm = 2) {
  const radiusDeg = radiusKm / 111; // Rough conversion
  const lat = centerLat + (Math.random() - 0.5) * radiusDeg * 2;
  const lng = centerLng + (Math.random() - 0.5) * radiusDeg * 2;
  return { lat, lng };
}

async function seed() {
  const client = await pool.connect();

  try {
    console.log('🌱 Starting database seed...\n');

    // Clear existing data (in reverse FK dependency order)
    console.log('🗑️  Clearing existing data...');
    await client.query('DELETE FROM ratings');
    await client.query('DELETE FROM payments');
    await client.query('DELETE FROM quotes');
    await client.query('DELETE FROM bookings');
    await client.query('DELETE FROM trips');
    await client.query('DELETE FROM users');
    console.log('✅ Existing data cleared\n');

    // Create 50 users (25 drivers, 25 riders)
    console.log('👥 Creating 50 users...');
    const userIds = [];
    const password_hash = await bcrypt.hash('Password123', 10);

    for (let i = 1; i <= 50; i++) {
      const isDriver = i <= 25;
      const role = isDriver ? 'Driver' : 'Rider';

      const result = await client.query(`
        INSERT INTO users (name, email, password_hash, role, sjsu_id_status, rating, vehicle_info, seats_available)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING user_id
      `, [
        faker.person.fullName(),
        `user${i}@sjsu.edu`,
        password_hash,
        role,
        'verified',
        parseFloat((Math.random() * 2 + 3).toFixed(2)), // 3.0-5.0 rating
        isDriver ? `${faker.vehicle.manufacturer()} ${faker.vehicle.model()}` : null,
        isDriver ? Math.floor(Math.random() * 4) + 1 : null, // 1-4 seats
      ]);

      userIds.push({ id: result.rows[0].user_id, role });
    }
    console.log(`✅ Created 50 users (25 drivers, 25 riders)\n`);

    // Create 100 trips
    console.log('🚗 Creating 100 trips...');
    const tripIds = [];
    const driverIds = userIds.filter(u => u.role === 'Driver').map(u => u.id);

    for (let i = 0; i < 100; i++) {
      const driverId = driverIds[Math.floor(Math.random() * driverIds.length)];
      const origin = randomNearby(SJSU_LAT, SJSU_LNG, 1);
      const dest = DESTINATIONS[Math.floor(Math.random() * DESTINATIONS.length)];

      const departureTime = new Date();
      departureTime.setDate(departureTime.getDate() + Math.floor(Math.random() * 7));
      departureTime.setHours(Math.floor(Math.random() * 10) + 7); // 7 AM - 5 PM

      const statuses = ['active', 'active', 'active', 'active', 'active', 'active', 'active', 'completed', 'completed', 'cancelled'];
      const status = statuses[i % 10];

      const result = await client.query(`
        INSERT INTO trips (
          driver_id, origin, destination,
          origin_point, destination_point,
          departure_time, seats_available, status
        ) VALUES (
          $1, $2, $3,
          ST_SetSRID(ST_MakePoint($4, $5), 4326),
          ST_SetSRID(ST_MakePoint($6, $7), 4326),
          $8, $9, $10
        ) RETURNING trip_id
      `, [
        driverId,
        `Near SJSU Campus, San Jose, CA`,
        dest.name,
        origin.lng, origin.lat,
        dest.lng, dest.lat,
        departureTime,
        Math.floor(Math.random() * 3) + 1, // 1-3 seats
        status,
      ]);

      tripIds.push({ id: result.rows[0].trip_id, status, driverId });
    }
    console.log(`✅ Created 100 trips (70 active, 20 completed, 10 cancelled)\n`);

    // Create 50 bookings
    console.log('📋 Creating 50 bookings...');
    const riderIds = userIds.filter(u => u.role === 'Rider').map(u => u.id);
    const bookingIds = [];

    for (let i = 0; i < 50; i++) {
      const trip = tripIds[i];
      const riderId = riderIds[Math.floor(Math.random() * riderIds.length)];

      // Prevent booking own trip
      if (trip.driverId === riderId) continue;

      const bookingStatus = trip.status === 'completed' ? 'completed' :
                          trip.status === 'cancelled' ? 'cancelled' :
                          i % 3 === 0 ? 'pending' : 'confirmed';

      const result = await client.query(`
        INSERT INTO bookings (trip_id, rider_id, status, seats_booked)
        VALUES ($1, $2, $3, $4)
        RETURNING booking_id
      `, [trip.id, riderId, bookingStatus, 1]);

      bookingIds.push({
        id: result.rows[0].booking_id,
        tripId: trip.id,
        riderId,
        driverId: trip.driverId,
        status: bookingStatus,
      });

      // Create quote for booking
      const maxPrice = parseFloat((Math.random() * 15 + 10).toFixed(2));
      await client.query(`
        INSERT INTO quotes (booking_id, max_price, final_price)
        VALUES ($1, $2, $3)
      `, [result.rows[0].booking_id, maxPrice, bookingStatus === 'confirmed' ? maxPrice : null]);

      // Create payment for confirmed bookings
      if (bookingStatus === 'confirmed' || bookingStatus === 'completed') {
        await client.query(`
          INSERT INTO payments (booking_id, stripe_payment_intent_id, amount, status)
          VALUES ($1, $2, $3, $4)
        `, [
          result.rows[0].booking_id,
          `pi_test_${Math.random().toString(36).substr(2, 9)}`,
          maxPrice,
          'captured',
        ]);
      }
    }
    console.log(`✅ Created 50 bookings with quotes and payments\n`);

    // Create ratings for completed bookings
    console.log('⭐ Creating ratings...');
    const completedBookings = bookingIds.filter(b => b.status === 'completed');

    for (const booking of completedBookings) {
      // Rider rates driver
      await client.query(`
        INSERT INTO ratings (booking_id, rater_id, ratee_id, score, comment)
        VALUES ($1, $2, $3, $4, $5)
      `, [
        booking.id,
        booking.riderId,
        booking.driverId,
        Math.floor(Math.random() * 2) + 4, // 4-5 stars
        faker.lorem.sentence(),
      ]);

      // Driver rates rider
      await client.query(`
        INSERT INTO ratings (booking_id, rater_id, ratee_id, score, comment)
        VALUES ($1, $2, $3, $4, $5)
      `, [
        booking.id,
        booking.driverId,
        booking.riderId,
        Math.floor(Math.random() * 2) + 4, // 4-5 stars
        faker.lorem.sentence(),
      ]);
    }
    console.log(`✅ Created ${completedBookings.length * 2} ratings\n`);

    // Update user average ratings
    console.log('📊 Updating user average ratings...');
    await client.query(`
      UPDATE users
      SET rating = COALESCE((
        SELECT AVG(score)
        FROM ratings
        WHERE ratee_id = users.user_id
      ), 0)
    `);
    console.log('✅ User ratings updated\n');

    console.log('🎉 Seed completed successfully!\n');
    console.log('Summary:');
    console.log('  - 50 users (25 drivers, 25 riders)');
    console.log('  - 100 trips (SJSU area)');
    console.log('  - 50 bookings with quotes');
    console.log('  - Payments for confirmed bookings');
    console.log(`  - ${completedBookings.length * 2} ratings`);
    console.log('\nTest credentials: user1@sjsu.edu through user50@sjsu.edu');
    console.log('Password for all: Password123\n');

  } catch (error) {
    console.error('❌ Seed failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

seed().catch(console.error);
