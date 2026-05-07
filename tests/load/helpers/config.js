// Shared k6 configuration for LessGo load tests
export const BASE_URL = __ENV.BASE_URL || 'http://136.109.119.177:80';

// Shared performance thresholds (applied per-scenario as needed)
export const THRESHOLDS = {
  // Trip discovery: P95 ≤ 500ms
  trip_discovery: {
    'http_req_duration{scenario:trip_discovery}': ['p(95)<500'],
    'http_req_failed{scenario:trip_discovery}': ['rate<0.01'],
  },
  // Quote/pricing: P95 ≤ 300ms
  quote_calculation: {
    'http_req_duration{scenario:quote_calculation}': ['p(95)<300'],
    'http_req_failed{scenario:quote_calculation}': ['rate<0.01'],
  },
  // Booking confirmation: end-to-end ≤ 2000ms
  booking_confirmation: {
    'http_req_duration{scenario:booking_confirmation}': ['p(95)<2000'],
    'http_req_failed{scenario:booking_confirmation}': ['rate<0.05'],
  },
};

// SJSU campus area coordinates used across scenarios
export const LOCATIONS = {
  sjsu:       { lat: 37.3352, lng: -121.8811 },
  downtown:   { lat: 37.3382, lng: -121.8863 },
  santana_row:{ lat: 37.3209, lng: -121.9476 },
  diridon:    { lat: 37.3294, lng: -121.9022 },
  milpitas:   { lat: 37.4323, lng: -121.8996 },
};
