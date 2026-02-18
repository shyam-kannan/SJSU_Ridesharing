const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const { faker } = require('@faker-js/faker');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// SJSU Campus coordinates (correct)
const SJSU = {
  name: 'San Jose State University, 1 Washington Sq, San Jose, CA',
  lat: 37.3352,
  lng: -121.8811,
};

// ── Named Bay Area pickup/dropoff hubs with real coordinates ────────────────
const HUBS = [
  // San Francisco
  {
    name: 'San Francisco Caltrain, 700 4th St, San Francisco, CA',
    lat: 37.7765, lng: -122.3953,
    count: 10, // trips in each direction
  },
  // Oakland
  {
    name: 'Oakland 12th St BART, 1245 Broadway, Oakland, CA',
    lat: 37.8036, lng: -122.2715,
    count: 6,
  },
  // Fremont
  {
    name: 'Fremont BART Station, 2000 BART Way, Fremont, CA',
    lat: 37.5577, lng: -121.9760,
    count: 8,
  },
  // Milpitas
  {
    name: 'Great Mall, 447 Great Mall Dr, Milpitas, CA',
    lat: 37.4147, lng: -121.9004,
    count: 5,
  },
  // Santa Clara
  {
    name: 'Santa Clara Caltrain, 1000 Railroad Ave, Santa Clara, CA',
    lat: 37.3528, lng: -121.9366,
    count: 5,
  },
  // Mountain View
  {
    name: 'Mountain View Caltrain, 600 W Evelyn Ave, Mountain View, CA',
    lat: 37.3939, lng: -122.0762,
    count: 5,
  },
  // Sunnyvale
  {
    name: 'Sunnyvale Caltrain, 121 Murphy Ave, Sunnyvale, CA',
    lat: 37.3787, lng: -122.0311,
    count: 4,
  },
  // Palo Alto
  {
    name: 'Palo Alto Caltrain, 95 University Ave, Palo Alto, CA',
    lat: 37.4432, lng: -122.1643,
    count: 5,
  },
  // Cupertino
  {
    name: 'Vallco Shopping Mall, 10123 N Wolfe Rd, Cupertino, CA',
    lat: 37.3541, lng: -122.0493,
    count: 3,
  },
  // Berkeley
  {
    name: 'Downtown Berkeley BART, 2160 Shattuck Ave, Berkeley, CA',
    lat: 37.8699, lng: -122.2680,
    count: 3,
  },
];

// Morning departure hours for trips TO SJSU (rush hour)
const MORNING_HOURS = [7, 7, 7, 8, 8, 8, 8, 9, 9, 12];
// Afternoon/evening hours for trips FROM SJSU
const AFTERNOON_HOURS = [15, 15, 16, 16, 16, 17, 17, 17, 18, 19];

function pickHour(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function pickMinute() {
  return [0, 15, 30, 45][Math.floor(Math.random() * 4)];
}

function futureDateWithHour(hour, minute) {
  const d = new Date();
  d.setDate(d.getDate() + Math.floor(Math.random() * 14) + 1); // 1–14 days out
  d.setHours(hour, minute, 0, 0);
  return d;
}

async function seed() {
  const client = await pool.connect();

  try {
    console.log('🌱 Starting database seed...\n');

    // ── Clear existing data (reverse FK order) ────────────────────────────
    console.log('🗑️  Clearing existing data...');
    await client.query('DELETE FROM ratings');
    await client.query('DELETE FROM payments');
    await client.query('DELETE FROM quotes');
    await client.query('DELETE FROM bookings');
    await client.query('DELETE FROM trips');
    await client.query('DELETE FROM users');
    console.log('✅ Existing data cleared\n');

    // ── Create 50 users (25 drivers, 25 riders) ───────────────────────────
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
        parseFloat((Math.random() * 2 + 3).toFixed(2)), // 3.0–5.0
        isDriver ? `${faker.vehicle.manufacturer()} ${faker.vehicle.model()}` : null,
        isDriver ? Math.floor(Math.random() * 4) + 1 : null,
      ]);

      userIds.push({ id: result.rows[0].user_id, role });
    }
    console.log('✅ Created 50 users (25 drivers, 25 riders)\n');

    // ── Create trips ──────────────────────────────────────────────────────
    console.log('🚗 Creating 100 trips (50 → SJSU, 50 ← SJSU)...');
    const tripIds = [];
    const driverIds = userIds.filter(u => u.role === 'Driver').map(u => u.id);

    let driverIndex = 0;
    const nextDriver = () => {
      const id = driverIds[driverIndex % driverIds.length];
      driverIndex++;
      return id;
    };

    // ── 50 trips TO SJSU ─────────────────────────────────────────────────
    for (const hub of HUBS) {
      for (let j = 0; j < hub.count; j++) {
        const driverId = nextDriver();
        const seats = Math.floor(Math.random() * 4) + 1; // 1–4
        const hour = pickHour(MORNING_HOURS);
        const minute = pickMinute();
        const departure = futureDateWithHour(hour, minute);

        // Trips 1–70 active, 71–85 completed, 86–100 cancelled
        // (mirrored across both directions by position)
        const tripNum = tripIds.length;
        const status = tripNum < 70 ? 'active' : tripNum < 85 ? 'completed' : 'cancelled';

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
          hub.name,
          SJSU.name,
          hub.lng, hub.lat,
          SJSU.lng, SJSU.lat,
          departure,
          seats,
          status,
        ]);

        tripIds.push({ id: result.rows[0].trip_id, status, driverId });
      }
    }

    // ── 50 trips FROM SJSU ───────────────────────────────────────────────
    for (const hub of HUBS) {
      for (let j = 0; j < hub.count; j++) {
        const driverId = nextDriver();
        const seats = Math.floor(Math.random() * 4) + 1;
        const hour = pickHour(AFTERNOON_HOURS);
        const minute = pickMinute();
        const departure = futureDateWithHour(hour, minute);

        const tripNum = tripIds.length;
        const status = tripNum < 70 ? 'active' : tripNum < 85 ? 'completed' : 'cancelled';

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
          SJSU.name,
          hub.name,
          SJSU.lng, SJSU.lat,
          hub.lng, hub.lat,
          departure,
          seats,
          status,
        ]);

        tripIds.push({ id: result.rows[0].trip_id, status, driverId });
      }
    }

    const activeCt    = tripIds.filter(t => t.status === 'active').length;
    const completedCt = tripIds.filter(t => t.status === 'completed').length;
    const cancelledCt = tripIds.filter(t => t.status === 'cancelled').length;
    console.log(`✅ Created ${tripIds.length} trips — ${activeCt} active, ${completedCt} completed, ${cancelledCt} cancelled\n`);

    // ── Create 50 bookings ────────────────────────────────────────────────
    console.log('📋 Creating 50 bookings...');
    const riderIds = userIds.filter(u => u.role === 'Rider').map(u => u.id);
    const bookingIds = [];

    // Interleave active (0-69) and completed (70-84) trips so we get ratings
    const bookingTripIndices = [
      ...Array.from({ length: 35 }, (_, i) => i),           // 35 active trips
      ...Array.from({ length: 15 }, (_, i) => 70 + i),      // 15 completed trips
    ];

    for (let i = 0; i < 50; i++) {
      const trip = tripIds[bookingTripIndices[i]];
      const riderId = riderIds[i % riderIds.length];

      if (trip.driverId === riderId) continue;

      const bookingStatus =
        trip.status === 'completed' ? 'completed' :
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

      const maxPrice = parseFloat((Math.random() * 15 + 5).toFixed(2));
      await client.query(`
        INSERT INTO quotes (booking_id, max_price, final_price)
        VALUES ($1, $2, $3)
      `, [result.rows[0].booking_id, maxPrice, bookingStatus === 'confirmed' ? maxPrice : null]);

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
    console.log(`✅ Created ${bookingIds.length} bookings with quotes and payments\n`);

    // ── Create ratings for completed bookings ─────────────────────────────
    console.log('⭐ Creating ratings...');
    const completedBookings = bookingIds.filter(b => b.status === 'completed');

    for (const booking of completedBookings) {
      await client.query(`
        INSERT INTO ratings (booking_id, rater_id, ratee_id, score, comment)
        VALUES ($1, $2, $3, $4, $5)
      `, [booking.id, booking.riderId, booking.driverId, Math.floor(Math.random() * 2) + 4, faker.lorem.sentence()]);

      await client.query(`
        INSERT INTO ratings (booking_id, rater_id, ratee_id, score, comment)
        VALUES ($1, $2, $3, $4, $5)
      `, [booking.id, booking.driverId, booking.riderId, Math.floor(Math.random() * 2) + 4, faker.lorem.sentence()]);
    }
    console.log(`✅ Created ${completedBookings.length * 2} ratings\n`);

    // ── Recalculate user average ratings ─────────────────────────────────
    console.log('📊 Updating user average ratings...');
    await client.query(`
      UPDATE users
      SET rating = COALESCE((
        SELECT AVG(score) FROM ratings WHERE ratee_id = users.user_id
      ), rating)
    `);
    console.log('✅ User ratings updated\n');

    // ── Summary ───────────────────────────────────────────────────────────
    console.log('🎉 Seed completed successfully!\n');
    console.log('Summary:');
    console.log('  - 50 users (25 drivers, 25 riders)');
    console.log(`  - ${tripIds.length} trips:`);
    for (const hub of HUBS) {
      console.log(`      ${hub.count} ↔ SJSU  |  ${hub.name}`);
    }
    console.log(`  - ${activeCt} active, ${completedCt} completed, ${cancelledCt} cancelled`);
    console.log(`  - ${bookingIds.length} bookings with quotes`);
    console.log(`  - ${completedBookings.length * 2} ratings`);
    console.log('\nTest credentials: user1@sjsu.edu – user50@sjsu.edu');
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
