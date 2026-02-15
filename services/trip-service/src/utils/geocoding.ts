import axios from 'axios';
import { config } from '../config';
import { GeoPoint } from '../../../shared/types';

/**
 * Geocode an address to lat/lng coordinates using Google Maps API
 * @param address Address string to geocode
 * @returns Geographic coordinates
 */
export const geocodeAddress = async (address: string): Promise<GeoPoint> => {
  if (!config.googleMapsApiKey) {
    throw new Error('Google Maps API key not configured');
  }

  try {
    const response = await axios.get('https://maps.googleapis.com/maps/api/geocode/json', {
      params: {
        address,
        key: config.googleMapsApiKey,
      },
    });

    if (response.data.status !== 'OK') {
      throw new Error(`Geocoding failed: ${response.data.status}`);
    }

    if (response.data.results.length === 0) {
      throw new Error('No results found for address');
    }

    const location = response.data.results[0].geometry.location;

    return {
      lat: location.lat,
      lng: location.lng,
    };
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Geocoding API error:', error.response?.data || error.message);
      throw new Error('Failed to geocode address');
    }
    throw error;
  }
};

/**
 * Reverse geocode coordinates to an address
 * @param lat Latitude
 * @param lng Longitude
 * @returns Formatted address
 */
export const reverseGeocode = async (lat: number, lng: number): Promise<string> => {
  if (!config.googleMapsApiKey) {
    throw new Error('Google Maps API key not configured');
  }

  try {
    const response = await axios.get('https://maps.googleapis.com/maps/api/geocode/json', {
      params: {
        latlng: `${lat},${lng}`,
        key: config.googleMapsApiKey,
      },
    });

    if (response.data.status !== 'OK') {
      throw new Error(`Reverse geocoding failed: ${response.data.status}`);
    }

    if (response.data.results.length === 0) {
      throw new Error('No address found for coordinates');
    }

    return response.data.results[0].formatted_address;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Reverse geocoding API error:', error.response?.data || error.message);
      throw new Error('Failed to reverse geocode coordinates');
    }
    throw error;
  }
};

/**
 * Validate and geocode both origin and destination
 * @param origin Origin address
 * @param destination Destination address
 * @returns Object with both geocoded points
 */
export const geocodeTripLocations = async (
  origin: string,
  destination: string
): Promise<{
  originPoint: GeoPoint;
  destinationPoint: GeoPoint;
}> => {
  try {
    // Geocode both addresses in parallel
    const [originPoint, destinationPoint] = await Promise.all([
      geocodeAddress(origin),
      geocodeAddress(destination),
    ]);

    return {
      originPoint,
      destinationPoint,
    };
  } catch (error) {
    throw error;
  }
};
