// gnss_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'gnss_detail_page.dart';

class GnssPage extends StatefulWidget {
  const GnssPage({Key? key}) : super(key: key);

  @override
  _GnssPageState createState() => _GnssPageState();
}

class _GnssPageState extends State<GnssPage> {
  List<String> gnssIds = [];
  String? selectedGnssId;
  List<dynamic> sensorData = [];
  List<Map<String, dynamic>> gnssCoords = [];

  final Map<String, String> sensorLabelMap = {
    'LAT': 'Latitude',
    'LAD': 'Latitude Direction',
    'LON': 'Longitude',
    'LOD': 'Longitude Direction',
    'SAT': 'Total Satellite for Position Lock',
    'ALT': 'Altitude',
    'GSE': 'Geodial Separation',
    'PDO': 'Position Dilution of Precision',
    'HDO': 'Horizontal Dilution of Precision',
    'VDO': 'Vertical Dilution of Precision',
    'SCO': 'Satellite Count (all)',
    'SNR': 'Signal Noise Ratio (First Satellite)',
    'MVR': 'Magnetic Value',
    'MVA': 'Magnetic Variation',
    'TEM': 'Temperature',
    'HUM': 'Humidity',
    'SPD': 'Speed',
    'HAD': 'Heading'
  };

  String getSensorLabel(String sensorId) {
    for (final entry in sensorLabelMap.entries) {
      if (sensorId.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return sensorId; // fallback
  }

  @override
  void initState() {
    super.initState();
    fetchGnssIds();
    fetchCoords();
  }

  Future<void> fetchGnssIds() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8080/api/gnss_ids'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> uniqueIds = data.map((e) => e.toString().trim()).toSet().toList();
        uniqueIds.sort((a, b) {
          final numA = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final numB = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
          return numA.compareTo(numB);
        });

        print("GNSS IDs fetched: $uniqueIds");

        setState(() {
          gnssIds = uniqueIds;
          if (selectedGnssId == null && gnssIds.isNotEmpty) {
            selectedGnssId = gnssIds[0];
            fetchSensorData(selectedGnssId!);
          }
        });
      } else {
        print('Failed to fetch GNSS IDs, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching GNSS IDs: $e');
    }
  }

  Future<void> fetchSensorData(String gnssId) async {
  try {
    final response = await http.get(Uri.parse('http://127.0.0.1:8080/api/gnss5'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      final Map<String, String> gnssSensorSuffixMap = {
        'GNSS1': '01',
        'GNSS2': '02',
        'GNSS3': '01',
        'GNSS4': '02',
        'GNSS5': '05',
      };

      final expectedSuffix = gnssSensorSuffixMap[gnssId] ?? '';

      // Filter by gnss_id, sensor_id suffix, and remove unwanted sensor types
      final filtered = data.where((item) {
        final itemGnssId = item['gnss_id'].toString().trim();
        final sensorId = item['sensor_id'].toString().trim();

        // Skip unwanted sensor types
        final isUnwanted = sensorId.startsWith('FXQ') || sensorId.startsWith('DAT') || sensorId.startsWith('UTC');

        return itemGnssId == gnssId && sensorId.endsWith(expectedSuffix) && !isUnwanted;
      }).toList();

      setState(() {
        sensorData = filtered;
      });
    } else {
      print('Failed to fetch sensor data. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching sensor data: $e');
  }
}


  Future<void> fetchCoords() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8080/api/gnss-coords'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print("GNSS Coords fetched: $data");
        setState(() {
          gnssCoords = List<Map<String, dynamic>>.from(data);
        });
      } else {
        print('Failed to fetch GNSS coords, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching GNSS coords: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedCoord;
try {
  selectedCoord = gnssCoords.firstWhere(
    (c) => c['gnss_id'].toString().trim() == selectedGnssId,
  );
} catch (e) {
  selectedCoord = null;
}


    if (selectedCoord == null) {
      print("No coordinates found for GNSS ID: $selectedGnssId");
    } else {
      print("Coordinates for $selectedGnssId: $selectedCoord");
    }

    final lat = selectedCoord != null ? selectedCoord['latitude'] : null;
    final lon = selectedCoord != null ? selectedCoord['longitude'] : null;
    final hasMapData = lat != null && lon != null;

    return Scaffold(
      appBar: AppBar(title: const Text('GNSS Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: const Text("Select GNSS ID"),
              value: selectedGnssId,
              items: gnssIds.map((id) {
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(id),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedGnssId = value;
                  sensorData = [];
                });
                if (value != null) {
                  fetchSensorData(value);
                }
              },
            ),
            const SizedBox(height: 16),
            hasMapData
                ? SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(lat, lon),
                        zoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 80,
                              height: 80,
                              point: LatLng(lat, lon),
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const Text("No coordinate data for selected GNSS."),
            const SizedBox(height: 16),
            Expanded(
              child: sensorData.isEmpty
                  ? const Center(child: Text('No data available'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: sensorData.length,
                      itemBuilder: (context, index) {
                        final data = sensorData[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GnssDetailPage(
                                  gnssId: selectedGnssId!,
                                  sensorId: data['sensor_id'],
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: Colors.blue[50],
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    getSensorLabel(data['sensor_id']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['sensor_id'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${data['value']}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blueAccent,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 2.0,
                                          color: Colors.black26,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Time: ${data['timestamp']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}