// gnss_detail_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'models/gnss_sensor.dart';

class GnssDetailPage extends StatefulWidget {
  final String sensorId;
  final String gnssId;

  const GnssDetailPage({
    Key? key,
    required this.sensorId,
    required this.gnssId,
  }) : super(key: key);

  @override
  _GnssDetailPageState createState() => _GnssDetailPageState();
}

class _GnssDetailPageState extends State<GnssDetailPage> {
  List<GnssSensor> dataPoints = [];
  DateTime? startDate;
  DateTime? endDate;

  bool isLoading = false;
  String? errorMessage;

  final Map<String, String> sensorDescriptions = {
  'LAT': 'The north-south position of the GNSS receiver on the Earth’s surface.',
  'LAD': 'Indicates whether the latitude is in the Northern or Southern Hemisphere.',
  'LON': 'The east-west position of the GNSS receiver on the Earth’s surface.',
  'LOD': 'Indicates whether the longitude is in the Eastern or Western Hemisphere.',
  'SAT': 'The number of satellites currently used to compute the GNSS position fix.',
  'ALT': 'The height of the GNSS receiver above mean sea level.',
  'GSE': 'The geodetic separation between the GNSS receiver and a reference ellipsoid, often representing geoid height.',
  'PDO': 'An indicator of the overall satellite geometry quality affecting position accuracy.',
  'HDO': 'A measure of how satellite geometry affects horizontal position accuracy.',
  'VDO': 'A measure of how satellite geometry affects vertical position accuracy.',
  'SCO': 'Total number of satellites detected, including those not used for the position fix.',
  'SNR': 'Quality of the GNSS signal received from the first satellite in view.',
  'MVR': 'Raw magnetic field reading at the GNSS receiver location.',
  'MVA': 'The angular difference between true north and magnetic north.',
  'TEM': 'The ambient temperature around the GNSS device.',
  'HUM': 'The level of moisture in the atmosphere at the sensor location.',
  'SPD': 'The current velocity of the GNSS receiver relative to the ground.',
  'HAD': 'The direction the GNSS receiver is moving, expressed in degrees from true north.'
};


  @override
  void initState() {
    super.initState();
    fetchDetailData();
  }

  Future<void> fetchDetailData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final start = startDate != null ? '&startDate=${startDate!.toIso8601String()}' : '';
    final end = endDate != null ? '&endDate=${endDate!.toIso8601String()}' : '';
    final limit = '&limit=1000';

    final String apiUrl =
        'http://127.0.0.1:8080/api/gnss-detail?gnssId=${widget.gnssId}&sensorId=${widget.sensorId}$start$end$limit';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        final sensors = data.map((json) => GnssSensor.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            dataPoints = sensors;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load detail data: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching detail data: $e';
        isLoading = false;
      });
    }
  }

  List<GnssSensor> _filteredData() {
    return dataPoints.where((point) {
      final pointTime = DateTime.parse(point.timestamp);
      if (startDate != null && pointTime.isBefore(startDate!)) return false;
      if (endDate != null && pointTime.isAfter(endDate!)) return false;
      return true;
    }).toList();
  }

  List<FlSpot> _generateSpots() {
    final filtered = _filteredData();
    const maxSpots = 300;
    if (filtered.length <= maxSpots) {
      return filtered.map((item) {
        final timestamp = DateTime.parse(item.timestamp).millisecondsSinceEpoch / 1000;
        final value = double.tryParse(item.value.toString()) ?? 0.0;
        return FlSpot(timestamp.toDouble(), value);
      }).toList();
    } else {
      final step = (filtered.length / maxSpots).ceil();
      List<FlSpot> spots = [];
      for (int i = 0; i < filtered.length; i += step) {
        final item = filtered[i];
        final timestamp = DateTime.parse(item.timestamp).millisecondsSinceEpoch / 1000;
        final value = double.tryParse(item.value.toString()) ?? 0.0;
        spots.add(FlSpot(timestamp.toDouble(), value));
      }
      return spots;
    }
  }

  double _calculateAverage() {
    final filtered = _filteredData();
    if (filtered.isEmpty) return 0.0;
    final values = filtered.map((e) => double.tryParse(e.value.toString()) ?? 0.0).toList();
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _findMin() {
    final filtered = _filteredData();
    if (filtered.isEmpty) return 0.0;
    return filtered.map((e) => double.tryParse(e.value.toString()) ?? 0.0).reduce((a, b) => a < b ? a : b);
  }

  double _findMax() {
    final filtered = _filteredData();
    if (filtered.isEmpty) return 0.0;
    return filtered.map((e) => double.tryParse(e.value.toString()) ?? 0.0).reduce((a, b) => a > b ? a : b);
  }

  Widget _buildStatCard(String title, double value) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
      });
      fetchDetailData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
      fetchDetailData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensorKey = widget.sensorId.substring(0, 3).toUpperCase();
    final aboutText = sensorDescriptions[sensorKey] ??
        'This parameter measures real-time sensor data associated with the GNSS device.';

    return Scaffold(
      appBar: AppBar(title: Text('Details for ${widget.sensorId}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: _selectStartDate,
                              child: Text(
                                startDate == null
                                    ? 'Select Start Date'
                                    : 'Start: ${startDate!.toLocal().toString().split(' ')[0]}',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _selectEndDate,
                              child: Text(
                                endDate == null
                                    ? 'Select End Date'
                                    : 'End: ${endDate!.toLocal().toString().split(' ')[0]}',
                              ),
                            ),
                          ],
                        ),
                        if (startDate != null || endDate != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                startDate = null;
                                endDate = null;
                              });
                              fetchDetailData();
                            },
                            child: const Text('Clear Date Filter'),
                          ),
                        const SizedBox(height: 16),
                        dataPoints.isEmpty
                            ? const Center(child: Text('No data available for the selected date range'))
                            : SizedBox(
                                height: 250,
                                child: LineChart(
                                  LineChartData(
                                    minY: _findMin(),
                                    maxY: _findMax(),
                                    gridData: FlGridData(show: true, drawVerticalLine: true),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 32,
                                          interval: 3600 * 12,
                                          getTitlesWidget: (value, meta) {
                                            final date = DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
                                            final label = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(label, style: const TextStyle(fontSize: 10)),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 10)),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: true),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _generateSpots(),
                                        isCurved: true,
                                        color: Colors.green,
                                        barWidth: 2,
                                        dotData: FlDotData(show: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        const SizedBox(height: 24),
                        dataPoints.isEmpty
                            ? const SizedBox()
                            : GridView.count(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                children: [
                                  _buildStatCard('Average Value', _calculateAverage()),
                                  _buildStatCard('Minimum Value', _findMin()),
                                  _buildStatCard('Maximum Value', _findMax()),
                                ],
                              ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'About',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  aboutText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}