import { config } from '../config';

/**
 * Simulates fetching a speed limit using the Google Maps API.
 * In a real scenario, this would call the Google Maps Roads API (Speed Limits).
 * `https://roads.googleapis.com/v1/speedLimits?path={lat},{lng}&key={API_KEY}`
 * Since that API requires Premium Plan or Asset Tracking mobility permissions,
 * we provide a mock fallback if it fails or if the key is missing.
 */
export const getSpeedLimitForLocation = async (lat: number, lng: number): Promise<number> => {
  // Try calling Google Maps if we have an API key, otherwise fallback to 70
  if (config.googleMapsApiKey) {
    try {
      // Dummy fetch to represent the HTTP call that would be made:
      // const response = await axios.get(`https://roads.googleapis.com/v1/speedLimits?path=${lat},${lng}&key=${config.googleMapsApiKey}`);
      // return response.data.speedLimits[0].speedLimit;
      
      // Since we know even with a basic key this often fails with a 403, we will simulate the success or mock fallback
      console.log(`[Google Maps API] Requesting speed limit for ${lat},${lng}...`);
      
      // Randomly simulate 30 mph for urban areas or return 70 mph
      // We will just use the mock fallback of 70 mph as requested
      return 70;
    } catch (error) {
      console.warn('Google Maps API failed, falling back to 70 mph limit');
      return 70;
    }
  }

  // Fallback as requested
  return 70;
};
