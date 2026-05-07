/**
 * Shared TypeScript types and interfaces for LessGo Backend
 */

// ========== ENUMS ==========

export enum UserRole {
  Driver = 'Driver',
  Rider = 'Rider',
}

export enum SJSUIdStatus {
  Pending = 'pending',
  Verified = 'verified',
  Rejected = 'rejected',
}

export enum TripStatus {
  Pending = 'pending',        // Trip created, waiting for driver to start
  EnRoute = 'en_route',       // Driver heading to pickup location
  Arrived = 'arrived',        // Driver at pickup location
  InProgress = 'in_progress', // Rider in car, heading to destination
  Completed = 'completed',    // Trip finished
  Cancelled = 'cancelled',    // Trip cancelled
}

export enum BookingStatus {
  Pending = 'pending',
  Confirmed = 'confirmed',
  Cancelled = 'cancelled',
  Completed = 'completed',
}

export enum BookingState {
  Pending = 'pending',      // Awaiting driver approval
  Approved = 'approved',    // Driver approved the booking
  Rejected = 'rejected',    // Driver rejected the booking
  Cancelled = 'cancelled',  // Booking cancelled by rider or driver
  Completed = 'completed',  // Trip completed
}

export enum PaymentStatus {
  Pending = 'pending',
  Captured = 'captured',
  Refunded = 'refunded',
  Failed = 'failed',
}

// ========== INTERFACES ==========

/**
 * User entity
 */
export interface User {
  user_id: string;
  name: string;
  email: string;
  password_hash: string;
  sjsu_id_status: SJSUIdStatus;
  sjsu_id_image_path?: string;
  role: UserRole;
  rating: number;
  vehicle_info?: string;
  seats_available?: number;
  mpg?: number;
  created_at: Date;
  updated_at: Date;
}

/**
 * User without sensitive data (for API responses)
 */
export interface SafeUser {
  user_id: string;
  name: string;
  email: string;
  sjsu_id_status: SJSUIdStatus;
  role: UserRole;
  rating: number;
  vehicle_info?: string;
  seats_available?: number;
  license_plate?: string;
  earnings?: number;
  profile_picture_url?: string | null;
  mpg?: number;
  stripe_connect_account_id?: string | null;
  created_at: Date;
  updated_at: Date;
}

/**
 * Geographic point
 */
export interface GeoPoint {
  lat: number;
  lng: number;
}

/**
 * Trip entity
 */
export interface Trip {
  trip_id: string;
  driver_id: string;
  origin: string;
  destination: string;
  origin_point: GeoPoint;
  destination_point: GeoPoint;
  departure_time: Date;
  seats_available: number;
  recurrence?: string;
  status: TripStatus;
  featured?: boolean;      // New field for promoting routes
  max_riders?: number;     // New field for max concurrent bookings
  pending_booking_count?: number; // Count of pending bookings for driver view
  created_at: Date;
  updated_at: Date;
}

/**
 * Trip with driver information
 */
export interface TripWithDriver extends Trip {
  driver: SafeUser;
}

/**
 * Booking entity
 */
export interface Booking {
  booking_id: string;
  trip_id: string;
  rider_id: string;
  status: BookingStatus;
  booking_state?: BookingState;
  seats_booked: number;
  fare?: number;
  payment_intent_id?: string | null;
  hold_expires_at?: Date | null;
  pickup_location?: { lat: number; lng: number } | null;
  created_at: Date;
  updated_at: Date;
}

/**
 * Booking with related entities
 */
export interface BookingWithDetails extends Booking {
  trip: TripWithDriver;
  rider: SafeUser;
  quote?: Quote;
  payment?: Payment;
}

/**
 * Quote entity
 */
export interface Quote {
  quote_id: string;
  booking_id: string;
  max_price: number;
  final_price?: number;
  created_at: Date;
}

/**
 * Payment entity
 */
export interface Payment {
  payment_id: string;
  booking_id: string;
  stripe_payment_intent_id?: string;
  amount: number;
  status: PaymentStatus;
  created_at: Date;
  updated_at: Date;
}

/**
 * Rating entity
 */
export interface Rating {
  rating_id: string;
  booking_id: string;
  rater_id: string;
  ratee_id: string;
  score: number;
  comment?: string;
  created_at: Date;
}

/**
 * Rating with user information
 */
export interface RatingWithUsers extends Rating {
  rater: SafeUser;
  ratee: SafeUser;
}

// ========== REQUEST/RESPONSE TYPES ==========

/**
 * Registration request body
 */
export interface RegisterRequest {
  name: string;
  email: string;
  password: string;
  role: UserRole;
}

/**
 * Login request body
 */
export interface LoginRequest {
  email: string;
  password: string;
}

/**
 * Authentication response with tokens
 */
export interface AuthResponse {
  user: SafeUser;
  accessToken: string;
  refreshToken: string;
}

/**
 * JWT token payload
 */
export interface JWTPayload {
  userId: string;
  email: string;
  role: UserRole;
  sjsuIdStatus: SJSUIdStatus;
  type: 'access' | 'refresh';
  iat?: number;
  exp?: number;
}

/**
 * Create trip request
 */
export interface CreateTripRequest {
  origin: string;
  destination: string;
  departure_time: string;
  seats_available: number;
  recurrence?: string;
}

/**
 * Search trips request
 */
export interface SearchTripsRequest {
  origin_lat: number;
  origin_lng: number;
  radius_meters?: number;
  min_seats?: number;
  departure_after?: string;
  departure_before?: string;
}

/**
 * Create booking request
 */
export interface CreateBookingRequest {
  trip_id: string;
  seats_booked: number;
  scost_breakdown?: ScostBreakdown;
}

/**
 * Scost breakdown from ML matching algorithm (He et al. eq 9)
 */
export interface ScostBreakdown {
  travel: number;   // Average detour distance per passenger
  walk: number;     // Walking distance from rider to driver origin
  detour: number;   // Extra distance penalty for adding passengers
  advance: number;  // Waiting time
  social: number;   // Route compatibility score
  total: number;    // Sum of all components
}

/**
 * Create rating request
 */
export interface CreateRatingRequest {
  score: number;
  comment?: string;
}

/**
 * Driver setup request
 */
export interface DriverSetupRequest {
  vehicle_info: string;
  seats_available: number;
  license_plate: string;
  mpg?: number;
}

// ========== API RESPONSE TYPES ==========

/**
 * Validation error structure
 */
export interface ValidationError {
  field?: string;
  message: string;
}

/**
 * Standard API success response
 */
export interface APISuccessResponse<T = unknown> {
  status: 'success';
  message: string;
  data: T;
}

/**
 * Standard API error response
 */
export interface APIErrorResponse {
  status: 'error';
  message: string;
  errors?: ValidationError[] | Record<string, string>;
}

/**
 * Paginated response
 */
export interface PaginatedResponse<T = unknown> {
  status: 'success';
  message: string;
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

// ========== SERVICE COMMUNICATION TYPES ==========

/**
 * Cost calculation request (for Cost Service)
 */
export interface CostCalculationRequest {
  origin: string;
  destination: string;
  num_riders: number;
  trip_id: string;
}

/**
 * Cost calculation response
 */
export interface CostCalculationResponse {
  max_price: number;
  breakdown: {
    base_price: number;
    distance_miles: number;
    price_per_mile: number;
    total_trip_cost: number;
    price_per_rider: number;
  };
}

/**
 * Route calculation request (for Routing Service)
 */
export interface RouteCalculationRequest {
  origin: string;
  destination: string;
}

/**
 * Route calculation response
 */
export interface RouteCalculationResponse {
  distance_meters: number;
  distance_miles: number;
  duration_seconds: number;
  polyline?: string;
}

/**
 * Trip matching request (for Grouping Service)
 */
export interface TripMatchingRequest {
  rider_id: string;
  origin_lat: number;
  origin_lng: number;
  destination_lat: number;
  destination_lng: number;
  departure_time: string;
  seats_needed: number;
}

/**
 * Trip matching response
 */
export interface TripMatchingResponse {
  matches: Array<{
    trip_id: string;
    score: number;
    distance_to_origin: number;
    distance_to_destination: number;
    available_seats: number;
  }>;
}

/**
 * Per-rider settlement result
 */
export interface RiderSettlement {
  rider_id: string;
  rider_name: string;
  amount_paid: number;
  status: string;
  detour_miles: number;
  breakdown: string;
}

/**
 * Full trip settlement result (returned by cost-calculation-service)
 */
export interface TripSettlement {
  trip_id: string;
  total_cost: number;
  driver_earnings: number;
  rider_count: number;
  cost_per_rider: number;
  breakdown: {
    base_price: number;
    distance_miles: number;
    price_per_mile: number;
  };
  riders: RiderSettlement[];
}
