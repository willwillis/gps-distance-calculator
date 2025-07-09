import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

void main() {
  runApp(const GPSDistanceApp());
}

class GPSDistanceApp extends StatelessWidget {
  const GPSDistanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Distance Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GPSDistancePage(),
    );
  }
}

class GPSDistancePage extends StatefulWidget {
  const GPSDistancePage({super.key});

  @override
  State<GPSDistancePage> createState() => _GPSDistancePageState();
}

class _GPSDistancePageState extends State<GPSDistancePage> {
  Position? _startPosition;
  Position? _endPosition;
  double? _distance;
  double? _realTimeDistance;
  bool _isLoading = false;
  bool _isTracking = false;
  bool _useFeet = false;
  String _statusMessage = 'Ready to record points';
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      await Permission.location.request();
    }
  }

  Future<Position?> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Getting current location...';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = 'Location services are disabled';
          _isLoading = false;
        });
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusMessage = 'Location permissions are denied';
            _isLoading = false;
          });
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusMessage = 'Location permissions are permanently denied';
          _isLoading = false;
        });
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _isLoading = false;
        _statusMessage = 'Location obtained successfully';
      });

      return position;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error getting location: $e';
      });
      return null;
    }
  }

  Future<void> _recordStartPoint() async {
    final position = await _getCurrentLocation();
    if (position != null) {
      setState(() {
        _startPosition = position;
        _statusMessage = 'Start point recorded - tracking active';
      });
      // Automatically start real-time tracking
      _startRealTimeTracking();
    }
  }

  Future<void> _recordEndPoint() async {
    final position = await _getCurrentLocation();
    if (position != null) {
      setState(() {
        _endPosition = position;
        _statusMessage = 'End point recorded - tracking stopped';
      });
      // Stop real-time tracking when end point is recorded
      _stopRealTimeTracking();
      _calculateDistance();
    }
  }

  void _calculateDistance() {
    if (_startPosition != null && _endPosition != null) {
      final start = LatLng(_startPosition!.latitude, _startPosition!.longitude);
      final end = LatLng(_endPosition!.latitude, _endPosition!.longitude);
      
      final distance = Geolocator.distanceBetween(
        _startPosition!.latitude,
        _startPosition!.longitude,
        _endPosition!.latitude,
        _endPosition!.longitude,
      );

      setState(() {
        _distance = distance;
        _statusMessage = 'Distance calculated';
      });
    }
  }

  void _startRealTimeTracking() async {
    if (_startPosition == null) {
      setState(() {
        _statusMessage = 'Please record a start point first';
      });
      return;
    }

    setState(() {
      _isTracking = true;
      _statusMessage = 'Real-time tracking active';
    });

    try {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // Update every 1 meter
        ),
      ).listen((Position position) {
        if (_isTracking && _startPosition != null) {
          final distance = Geolocator.distanceBetween(
            _startPosition!.latitude,
            _startPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          setState(() {
            _realTimeDistance = distance;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isTracking = false;
        _statusMessage = 'Error starting tracking: $e';
      });
    }
  }

  void _stopRealTimeTracking() {
    _positionStream?.cancel();
    setState(() {
      _isTracking = false;
      _realTimeDistance = null;
      _statusMessage = 'Real-time tracking stopped';
    });
  }

  void _toggleUnits() {
    setState(() {
      _useFeet = !_useFeet;
    });
  }

  void _reset() {
    _stopRealTimeTracking();
    setState(() {
      _startPosition = null;
      _endPosition = null;
      _distance = null;
      _realTimeDistance = null;
      _statusMessage = 'Ready to record points';
    });
  }

  String _formatDistance(double distance) {
    if (_useFeet) {
      // Convert meters to feet (1 meter = 3.28084 feet)
      final feet = distance * 3.28084;
      if (feet < 5280) { // Less than 1 mile
        return '${feet.toStringAsFixed(2)} feet';
      } else {
        return '${(feet / 5280).toStringAsFixed(2)} miles';
      }
    } else {
      if (distance < 1000) {
        return '${distance.toStringAsFixed(2)} meters';
      } else {
        return '${(distance / 1000).toStringAsFixed(2)} kilometers';
      }
    }
  }

  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Distance Calculator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isLoading ? Icons.gps_fixed : Icons.gps_not_fixed,
                      size: 48,
                      color: _isLoading ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Start Point Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trip_origin, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Start Point',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_startPosition != null)
                      Text(
                        _formatCoordinates(_startPosition!.latitude, _startPosition!.longitude),
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Text(
                        'Not recorded',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // End Point Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'End Point',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_endPosition != null)
                      Text(
                        _formatCoordinates(_endPosition!.latitude, _endPosition!.longitude),
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Text(
                        'Not recorded',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Real-time Distance Card
            if (_realTimeDistance != null)
              Card(
                color: Colors.orange.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.track_changes,
                            size: 32,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Real-time Distance',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDistance(_realTimeDistance!),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Distance Card
            if (_distance != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Final Distance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDistance(_distance!),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Unit Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Units:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Switch(
                      value: _useFeet,
                      onChanged: (value) => _toggleUnits(),
                    ),
                    Text(
                      _useFeet ? 'Feet/Miles' : 'Meters/Km',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _recordStartPoint,
                    icon: const Icon(Icons.trip_origin),
                    label: const Text('Record Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _recordEndPoint,
                    icon: const Icon(Icons.place),
                    label: const Text('Record End'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            

            
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
