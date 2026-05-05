/**
 * Validation utility functions
 */

/**
 * Validate email format
 * @param email Email address to validate
 * @returns True if valid email format
 * @example
 * ```ts
 * isValidEmail('user@example.com') // true
 * isValidEmail('invalid-email') // false
 * ```
 */
export const isValidEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Validate SJSU email specifically
 * @param email Email address to validate
 * @returns True if valid SJSU email
 * @example
 * ```ts
 * isValidSJSUEmail('user@sjsu.edu') // true
 * isValidSJSUEmail('user@example.com') // false
 * ```
 */
export const isValidSJSUEmail = (email: string): boolean => {
  const sjsuEmailRegex = /^[^\s@]+@sjsu\.edu$/i;
  return sjsuEmailRegex.test(email);
};

/**
 * Validate UUID format
 * @param uuid UUID string to validate
 * @returns True if valid UUID
 * @example
 * ```ts
 * isValidUUID('550e8400-e29b-41d4-a716-446655440000') // true
 * isValidUUID('invalid-uuid') // false
 * ```
 */
export const isValidUUID = (uuid: string): boolean => {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(uuid);
};

/**
 * Validate password strength
 * Password must be at least 8 characters with 1 uppercase, 1 lowercase, 1 number
 * @param password Password to validate
 * @returns Object with isValid flag and error message
 * @example
 * ```ts
 * validatePassword('Password1') // { isValid: true }
 * validatePassword('weak') // { isValid: false, message: 'Password must be at least 8 characters long' }
 * ```
 */
export const validatePassword = (
  password: string
): { isValid: boolean; message?: string } => {
  if (!password || password.length < 8) {
    return {
      isValid: false,
      message: 'Password must be at least 8 characters long',
    };
  }

  if (!/[A-Z]/.test(password)) {
    return {
      isValid: false,
      message: 'Password must contain at least one uppercase letter',
    };
  }

  if (!/[a-z]/.test(password)) {
    return {
      isValid: false,
      message: 'Password must contain at least one lowercase letter',
    };
  }

  if (!/[0-9]/.test(password)) {
    return {
      isValid: false,
      message: 'Password must contain at least one number',
    };
  }

  return { isValid: true };
};

/**
 * Validate latitude value
 * @param lat Latitude value
 * @returns True if valid latitude (-90 to 90)
 * @example
 * ```ts
 * isValidLatitude(37.3352) // true (SJSU latitude)
 * isValidLatitude(100) // false
 * ```
 */
export const isValidLatitude = (lat: number): boolean => {
  return typeof lat === 'number' && lat >= -90 && lat <= 90;
};

/**
 * Validate longitude value
 * @param lng Longitude value
 * @returns True if valid longitude (-180 to 180)
 * @example
 * ```ts
 * isValidLongitude(-122.8811) // true (SJSU longitude)
 * isValidLongitude(200) // false
 * ```
 */
export const isValidLongitude = (lng: number): boolean => {
  return typeof lng === 'number' && lng >= -180 && lng <= 180;
};

/**
 * Validate phone number (basic US format)
 * @param phone Phone number to validate
 * @returns True if valid phone format
 * @example
 * ```ts
 * isValidPhone('(408) 555-1234') // true
 * isValidPhone('408-555-1234') // true
 * isValidPhone('invalid') // false
 * ```
 */
export const isValidPhone = (phone: string): boolean => {
  const phoneRegex = /^\+?1?[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}$/;
  return phoneRegex.test(phone);
};

/**
 * Sanitize string input (remove potentially dangerous characters)
 * @param input String to sanitize
 * @returns Sanitized string
 * @example
 * ```ts
 * sanitizeString('  <script>alert("xss")</script>  ') // 'scriptalert("xss")/script'
 * ```
 */
export const sanitizeString = (input: string): string => {
  return input.trim().replace(/[<>]/g, '');
};

/**
 * Validate rating score (1-5)
 * @param score Rating score
 * @returns True if valid rating
 * @example
 * ```ts
 * isValidRating(5) // true
 * isValidRating(0) // false
 * isValidRating(6) // false
 * ```
 */
export const isValidRating = (score: number): boolean => {
  return Number.isInteger(score) && score >= 1 && score <= 5;
};

/**
 * Validate positive integer
 * @param value Value to validate
 * @returns True if positive integer
 * @example
 * ```ts
 * isPositiveInteger(5) // true
 * isPositiveInteger(0) // false
 * isPositiveInteger(-1) // false
 * isPositiveInteger(1.5) // false
 * ```
 */
export const isPositiveInteger = (value: number): boolean => {
  return Number.isInteger(value) && value > 0;
};

/**
 * Validate future date
 * @param date Date to validate
 * @returns True if date is in the future
 * @example
 * ```ts
 * isFutureDate(new Date('2099-01-01')) // true
 * isFutureDate(new Date('2020-01-01')) // false
 * ```
 */
export const isFutureDate = (date: Date): boolean => {
  return date.getTime() > Date.now();
};
