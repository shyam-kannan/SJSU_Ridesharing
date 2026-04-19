import { describe, expect, it } from 'vitest';
import {
  isFutureDate,
  isPositiveInteger,
  isValidEmail,
  isValidLatitude,
  isValidLongitude,
  isValidPhone,
  isValidRating,
  isValidSJSUEmail,
  isValidUUID,
  sanitizeString,
  validatePassword,
} from '../../shared/utils/validation';

describe('shared/utils/validation', () => {
  it('validates common email formats', () => {
    expect(isValidEmail('student@sjsu.edu')).toBe(true);
    expect(isValidEmail('not-an-email')).toBe(false);
  });

  it('validates SJSU emails case-insensitively', () => {
    expect(isValidSJSUEmail('student@sjsu.edu')).toBe(true);
    expect(isValidSJSUEmail('student@SJSU.EDU')).toBe(true);
    expect(isValidSJSUEmail('student@example.com')).toBe(false);
  });

  it('validates UUID values', () => {
    expect(isValidUUID('123e4567-e89b-12d3-a456-426614174000')).toBe(true);
    expect(isValidUUID('invalid-uuid')).toBe(false);
  });

  it('reports specific password validation failures', () => {
    expect(validatePassword('short')).toEqual({
      isValid: false,
      message: 'Password must be at least 8 characters long',
    });
    expect(validatePassword('lowercase1')).toEqual({
      isValid: false,
      message: 'Password must contain at least one uppercase letter',
    });
    expect(validatePassword('UPPERCASE1')).toEqual({
      isValid: false,
      message: 'Password must contain at least one lowercase letter',
    });
    expect(validatePassword('MissingNumber')).toEqual({
      isValid: false,
      message: 'Password must contain at least one number',
    });
    expect(validatePassword('ValidPass1')).toEqual({
      isValid: true,
    });
  });

  it('validates latitude and longitude bounds', () => {
    expect(isValidLatitude(37.3352)).toBe(true);
    expect(isValidLatitude(91)).toBe(false);
    expect(isValidLongitude(-121.8811)).toBe(true);
    expect(isValidLongitude(-181)).toBe(false);
  });

  it('validates common phone number formats', () => {
    expect(isValidPhone('+1 (408) 555-1234')).toBe(true);
    expect(isValidPhone('4085551234')).toBe(true);
    expect(isValidPhone('abc')).toBe(false);
  });

  it('sanitizes angle brackets and trims whitespace', () => {
    expect(sanitizeString('  <Hello>  ')).toBe('Hello');
  });

  it('validates rating, positive integers, and future dates', () => {
    expect(isValidRating(5)).toBe(true);
    expect(isValidRating(0)).toBe(false);
    expect(isPositiveInteger(3)).toBe(true);
    expect(isPositiveInteger(-1)).toBe(false);
    expect(isFutureDate(new Date(Date.now() + 60_000))).toBe(true);
    expect(isFutureDate(new Date(Date.now() - 60_000))).toBe(false);
  });
});