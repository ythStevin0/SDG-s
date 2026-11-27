import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/engine.dart';
import '../core/models.dart';

class WarehouseMapCard extends StatelessWidget {
  final String farmerKabupaten;
  final List<WarehouseItem> warehouses;
  final ValueChanged<WarehouseItem>? onSelectWarehouse;

  const WarehouseMapCard({
    super.key,
    required this.farmerKabupaten,
    required this.warehouses,
    this.onSelectWarehouse,
  });

  @override
  Widget build(BuildContext context) {
    final farmerCoord = SimpanJualEngine.resolveCoords(farmerKabupaten);
    final center = LatLng(farmerCoord[0], farmerCoord[1]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 230,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 9.2,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'id.simpanjual.mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 110,
                      height: 54,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Stok ($farmerKabupaten)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.agriculture, color: Color(0xFF0F172A), size: 26),
                        ],
                      ),
                    ),
                    ...warehouses.map((wh) {
                      final color = !wh.score.isEligible
                          ? Colors.grey.shade600
                          : wh.isSrg
                              ? const Color(0xFF047857)
                              : const Color(0xFF1D4ED8);
                      return Marker(
                        point: LatLng(wh.lat, wh.lng),
                        width: 96,
                        height: 56,
                        child: GestureDetector(
                          onTap: () => onSelectWarehouse?.call(wh),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  wh.score.isEligible ? 'Skor ${wh.score.totalScore}' : 'N/A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(Icons.warehouse_rounded, color: color, size: 26),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '© OpenStreetMap · Ketuk pin gudang untuk detail',
                  style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
