export interface RegionCoord {
  kabupaten: string;
  provinsi: string;
  lat: number;
  lng: number;
}

export const JATENG_REGIONS: Record<string, RegionCoord> = {
  Banyumas: { kabupaten: 'Banyumas', provinsi: 'Jawa Tengah', lat: -7.4502, lng: 109.1623 },
  Cilacap: { kabupaten: 'Cilacap', provinsi: 'Jawa Tengah', lat: -7.7188, lng: 109.0154 },
  Purbalingga: { kabupaten: 'Purbalingga', provinsi: 'Jawa Tengah', lat: -7.3881, lng: 109.3639 },
  Banjarnegara: { kabupaten: 'Banjarnegara', provinsi: 'Jawa Tengah', lat: -7.3987, lng: 109.6967 },
  Kebumen: { kabupaten: 'Kebumen', provinsi: 'Jawa Tengah', lat: -7.6691, lng: 109.6531 },
  Brebes: { kabupaten: 'Brebes', provinsi: 'Jawa Tengah', lat: -6.8706, lng: 109.0442 },
  Tegal: { kabupaten: 'Tegal', provinsi: 'Jawa Tengah', lat: -6.9932, lng: 109.1376 },
  Pemalang: { kabupaten: 'Pemalang', provinsi: 'Jawa Tengah', lat: -6.8894, lng: 109.3806 },
  Demak: { kabupaten: 'Demak', provinsi: 'Jawa Tengah', lat: -6.8909, lng: 110.6396 },
};

export const REGION_NAMES = Object.keys(JATENG_REGIONS);

export function resolveCoordinates(
  kabupaten: string,
  lat?: number | null,
  lng?: number | null
): { lat: number; lng: number } {
  if (typeof lat === 'number' && typeof lng === 'number' && Number.isFinite(lat) && Number.isFinite(lng)) {
    return { lat, lng };
  }
  const found = JATENG_REGIONS[kabupaten];
  if (found) {
    return { lat: found.lat, lng: found.lng };
  }
  return { lat: -7.4502, lng: 109.1623 }; // Default Banyumas
}

export function haversineKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const R = 6371;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const sinLat = Math.sin(dLat / 2);
  const sinLng = Math.sin(dLng / 2);
  const h =
    sinLat * sinLat + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * sinLng * sinLng;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function estimatedRoadDistanceKm(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number }
): number {
  return Number((haversineKm(a, b) * 1.3).toFixed(1));
}
