package engine

import "math"

type RegionCoord struct {
	Kabupaten string  `json:"kabupaten"`
	Provinsi  string  `json:"provinsi"`
	Lat       float64 `json:"lat"`
	Lng       float64 `json:"lng"`
}

var JatengRegions = map[string]RegionCoord{
	"Banyumas":     {Kabupaten: "Banyumas", Provinsi: "Jawa Tengah", Lat: -7.4502, Lng: 109.1623},
	"Cilacap":      {Kabupaten: "Cilacap", Provinsi: "Jawa Tengah", Lat: -7.7188, Lng: 109.0154},
	"Purbalingga":  {Kabupaten: "Purbalingga", Provinsi: "Jawa Tengah", Lat: -7.3881, Lng: 109.3639},
	"Banjarnegara": {Kabupaten: "Banjarnegara", Provinsi: "Jawa Tengah", Lat: -7.3987, Lng: 109.6967},
	"Kebumen":      {Kabupaten: "Kebumen", Provinsi: "Jawa Tengah", Lat: -7.6691, Lng: 109.6531},
	"Brebes":       {Kabupaten: "Brebes", Provinsi: "Jawa Tengah", Lat: -6.8706, Lng: 109.0442},
	"Tegal":        {Kabupaten: "Tegal", Provinsi: "Jawa Tengah", Lat: -6.9932, Lng: 109.1376},
	"Pemalang":     {Kabupaten: "Pemalang", Provinsi: "Jawa Tengah", Lat: -6.8894, Lng: 109.3806},
	"Demak":        {Kabupaten: "Demak", Provinsi: "Jawa Tengah", Lat: -6.8909, Lng: 110.6396},
}

func ResolveCoordinates(kabupaten string, lat, lng *float64) (float64, float64) {
	if lat != nil && lng != nil && !math.IsNaN(*lat) && !math.IsNaN(*lng) && !math.IsInf(*lat, 0) && !math.IsInf(*lng, 0) {
		return *lat, *lng
	}
	if found, ok := JatengRegions[kabupaten]; ok {
		return found.Lat, found.Lng
	}
	return -7.4502, 109.1623 // Default Banyumas
}

func HaversineKm(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371.0
	toRad := func(deg float64) float64 { return deg * math.Pi / 180.0 }
	dLat := toRad(lat2 - lat1)
	dLng := toRad(lng2 - lng1)
	sinLat := math.Sin(dLat / 2.0)
	sinLng := math.Sin(dLng / 2.0)
	h := sinLat*sinLat + math.Cos(toRad(lat1))*math.Cos(toRad(lat2))*sinLng*sinLng
	return 2.0 * R * math.Asin(math.Min(1.0, math.Sqrt(h)))
}

func EstimatedRoadDistanceKm(lat1, lng1, lat2, lng2 float64) float64 {
	return round1(HaversineKm(lat1, lng1, lat2, lng2) * 1.3)
}

func jsRound(v float64) int {
	return int(math.Floor(v + 0.5))
}

func round1(v float64) float64 {
	return math.Round(v*10.0) / 10.0
}

func round2(v float64) float64 {
	return math.Round(v*100.0) / 100.0
}

func clamp(val, minV, maxV float64) float64 {
	if val < minV {
		return minV
	}
	if val > maxV {
		return maxV
	}
	return val
}
