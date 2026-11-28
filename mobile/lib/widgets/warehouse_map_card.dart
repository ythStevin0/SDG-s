import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/engine.dart';
import '../core/models.dart';
import '../core/theme.dart';

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
    final p = SimpanJualPalette.of(context);
    final farmerCoord = SimpanJualEngine.resolveCoords(farmerKabupaten);
    final center = LatLng(farmerCoord[0], farmerCoord[1]);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      height: 236,
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
                    width: 118,
                    height: 56,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1917),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lokasi ($farmerKabupaten)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.agriculture, color: Color(0xFF1C1917), size: 26),
                      ],
                    ),
                  ),
                  ...warehouses.map((wh) {
                    final pinBg = !wh.score.isEligible
                        ? const Color(0xFF57534E)
                        : wh.isSrg
                            ? const Color(0xFF163A2A)
                            : const Color(0xFF9A4206);
                    return Marker(
                      point: LatLng(wh.lat, wh.lng),
                      width: 104,
                      height: 58,
                      child: Semantics(
                        button: true,
                        label: 'Pilih gudang ${wh.nama}',
                        child: GestureDetector(
                          onTap: () => onSelectWarehouse?.call(wh),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pinBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  wh.score.isEligible ? 'Skor ${wh.score.totalScore}' : 'Penuh/Tdk Cocok',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.warehouse_rounded, color: pinBg, size: 26),
                            ],
                          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F0),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF787063)),
              ),
              child: const Text(
                'Peta OpenStreetMap: ketuk pin gudang untuk mengajukan sewa',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1917),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
