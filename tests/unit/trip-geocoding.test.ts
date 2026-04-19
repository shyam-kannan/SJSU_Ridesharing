import { beforeEach, describe, expect, it, vi } from 'vitest';

const axiosGet = vi.fn();
const axiosIsAxiosError = vi.fn();

vi.mock('axios', () => ({
  default: {
    get: axiosGet,
    isAxiosError: axiosIsAxiosError,
  },
}));

vi.mock('../../services/trip-service/src/config', () => ({
  config: {
    googleMapsApiKey: 'test-google-maps-key',
  },
}));

describe('services/trip-service/src/utils/geocoding', () => {
  beforeEach(() => {
    axiosGet.mockReset();
    axiosIsAxiosError.mockReset();
    axiosIsAxiosError.mockReturnValue(false);
  });

  it('geocodes a single address into coordinates', async () => {
    axiosGet.mockResolvedValueOnce({
      data: {
        status: 'OK',
        results: [
          {
            geometry: {
              location: { lat: 37.3352, lng: -121.8811 },
            },
          },
        ],
      },
    });

    const { geocodeAddress } = await import('../../services/trip-service/src/utils/geocoding');
    const result = await geocodeAddress('San Jose State University');

    expect(result).toEqual({
      lat: 37.3352,
      lng: -121.8811,
    });
    expect(axiosGet).toHaveBeenCalledWith(
      'https://maps.googleapis.com/maps/api/geocode/json',
      expect.objectContaining({
        params: {
          address: 'San Jose State University',
          key: 'test-google-maps-key',
        },
      })
    );
  });

  it('throws when the geocoding provider returns no results', async () => {
    axiosGet.mockResolvedValueOnce({
      data: {
        status: 'OK',
        results: [],
      },
    });

    const { geocodeAddress } = await import('../../services/trip-service/src/utils/geocoding');

    await expect(geocodeAddress('Unknown address')).rejects.toThrow(
      'Geocoding failed: No results found for address'
    );
  });

  it('reverse geocodes coordinates into an address', async () => {
    axiosGet.mockResolvedValueOnce({
      data: {
        status: 'OK',
        results: [
          {
            formatted_address: '1 Washington Sq, San Jose, CA 95192, USA',
          },
        ],
      },
    });

    const { reverseGeocode } = await import('../../services/trip-service/src/utils/geocoding');
    const result = await reverseGeocode(37.3352, -121.8811);

    expect(result).toBe('1 Washington Sq, San Jose, CA 95192, USA');
  });

  it('geocodes origin and destination in parallel', async () => {
    axiosGet
      .mockResolvedValueOnce({
        data: {
          status: 'OK',
          results: [
            {
              geometry: {
                location: { lat: 37.3352, lng: -121.8811 },
              },
            },
          ],
        },
      })
      .mockResolvedValueOnce({
        data: {
          status: 'OK',
          results: [
            {
              geometry: {
                location: { lat: 37.422, lng: -122.0841 },
              },
            },
          ],
        },
      });

    const { geocodeTripLocations } = await import('../../services/trip-service/src/utils/geocoding');
    const result = await geocodeTripLocations('SJSU', 'Googleplex');

    expect(result).toEqual({
      originPoint: { lat: 37.3352, lng: -121.8811 },
      destinationPoint: { lat: 37.422, lng: -122.0841 },
    });
    expect(axiosGet).toHaveBeenCalledTimes(2);
  });
});