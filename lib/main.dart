import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

var timer = null;

var jsonString2 = '{	"objectsInBox":	[], "count": { "2": 0 }}';

class Entity {
  final int id;
  final double lat;
  final double lon;
  final String classId;

  const Entity(
      {required this.id,
      required this.lat,
      required this.lon,
      required this.classId});

  factory Entity.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': int id,
        'lat': double lat,
        'lon': double lon,
        'classId': String classId,
      } =>
        Entity(
          id: id,
          lat: lat,
          lon: lon,
          classId: classId,
        ),
      _ => throw const FormatException('Failed to load album.'),
    };
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaffleWizzards',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MyHomePage(
        title: 'WaffleWizzards',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double currentZoom = 13.0;
  bool start = true;
  var data = {};
  MapController _controller = MapController();
  LatLng currentCenter = LatLng(39.958262573044244, -86.12684814038774);
  void _zoomOut() {
    if (currentZoom >= 4) {
      currentZoom = currentZoom - 1;
      _controller.move(currentCenter, currentZoom);
    }
  }

  void _zoomIn() {
    if (currentZoom <= 17) {
      currentZoom = currentZoom + 1;
      _controller.move(currentCenter, currentZoom);
    }
  }

  @override
  void initState() {
    data = json.decode(jsonString2);

    // _getCurrentLocation();
    super.initState();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentCenter = LatLng(position.latitude, position.longitude);
      });
      _controller.move(
          LatLng(currentCenter.latitude, currentCenter.longitude), 13);
    } catch (e) {
      print(e);
    }
  }

  Future<dynamic> createAlbum() async {
    double bigLat1 = _startPoint.latitude;
    double bigLon1 = _startPoint.latitude;
    if (_startPoint.latitude > _endPoint.latitude) {
      bigLat1 = _startPoint.latitude;
      _startPoint.latitude = _endPoint.latitude;
      _endPoint.latitude = bigLat1;
    }
    if (_startPoint.longitude > _endPoint.longitude) {
      bigLon1 = _startPoint.longitude;
      _startPoint.longitude = _endPoint.longitude;
      _endPoint.longitude = bigLon1;
    }

    final response = await http.post(
      Uri.parse('http://9226-141-89-221-182.ngrok-free.app/box'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, double>{
        "lat1": _startPoint.latitude,
        "lon1": _startPoint.longitude,
        "lat2": _endPoint.latitude,
        "lon2": _endPoint.longitude,
      }),
    );
    if (response.statusCode == 200) {
      // If the server did return a 201 CREATED response,
      // then parse the JSON.
      return await jsonDecode(response.body);
      // return Entity.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      // If the server did not return a 201 CREATED response,
      // then throw an exception.
      throw Exception('Failed to create album.');
    }
  }

  LatLng _startPoint = LatLng(0, 0); // Starting point of rectangle
  LatLng _endPoint = LatLng(0, 0); // Ending point of rectangle
  LatLngBounds _rectangleBounds =
      LatLngBounds(); // Bounds to keep track of rectangle

  void getMarkers() async {
    try {
      var newData = await createAlbum();
      setState(() {
        data = newData;
      });
    } catch (e) {
      print('Error updating markers: $e');
    }
    print(data["objectsInBox"].length);
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          data["objectsInBox"].length.toString() +
              " Fahrzeuge in deinem ausgewählten Bereich",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FlutterMap(
        mapController: _controller,
        options: MapOptions(
            center: currentCenter, // Initial position (Potsdam)
            onTap: (tapPosition) {
              setState(() {
                if (start) {
                  _startPoint = tapPosition;
                  _rectangleBounds = LatLngBounds();
                  _rectangleBounds.extend(_startPoint);
                  _endPoint = _startPoint;
                  start = false;
                } else if (!start) {
                  _endPoint = tapPosition;
                  _rectangleBounds.extend(_endPoint);
                  start = true;
                  getMarkers();
                  if (timer != null) {
                    timer.cancel();
                  }
                  timer = Timer.periodic(
                      Duration(milliseconds: 400), (t) => getMarkers());
                }
              });
            },
            zoom: currentZoom,
            onPositionChanged: (position, hasGesture) {
              currentCenter = position.center as LatLng;
            }),
        layers: [
          TileLayerOptions(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'], // List of available subdomains
          ),
          MarkerLayerOptions(
            markers: [
              Marker(
                width: 30.0,
                height: 30.0,
                point: _startPoint,
                builder: (ctx) => Container(
                  child: Icon(
                    Icons.circle,
                    color: Colors.black,
                    size: 15,
                  ),
                ),
              ),
              Marker(
                width: 30.0,
                height: 30.0,
                point: _endPoint,
                builder: (ctx) => Container(
                  child: Icon(
                    Icons.circle,
                    color: Colors.black,
                    size: 15,
                  ),
                ),
              ),
              for (var i = 0; i < data["objectsInBox"].length; i++)
                Marker(
                    width: 5,
                    height: 5,
                    point: LatLng(data["objectsInBox"]![i]["lat"],
                        data["objectsInBox"][i]["lon"]),
                    builder: (ctx) => Container(
                          child: Icon(
                            data["objectsInBox"]![i]["classId"] == 2
                                ? Icons.directions_car_outlined
                                : Icons.directions_bike_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                        )),
            ],
          ),
          PolygonLayerOptions(
            polygons: [
              Polygon(
                points: [
                  _startPoint,
                  LatLng(_startPoint.latitude, _endPoint.longitude),
                  _endPoint,
                  LatLng(_endPoint.latitude, _startPoint.longitude),
                ],
                color: Colors.grey
                    .withOpacity(0.5), // Set the fill color with opacity
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Spacer(flex: 100),
          FloatingActionButton(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            onPressed: _zoomOut,
            tooltip: 'Zoom',
            child: Icon(Icons.remove_circle_outline_rounded),
          ),
          Spacer(flex: 1),
          FloatingActionButton(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            onPressed: _zoomIn,
            tooltip: 'Zoom',
            child: Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
