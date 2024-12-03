import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shake/shake.dart';

import 'dataBase.dart';





class FinderPage extends StatefulWidget {
  final VoidCallback onCaptureSuccess;

  const FinderPage({Key? key, required this.onCaptureSuccess}) : super(key: key);

  @override
  _FinderPageExtend createState() => _FinderPageExtend();
}

class _FinderPageExtend extends State<FinderPage> {
  final MapController _mapController = MapController();
  //LatLng _currentPosition = LatLng(39, -77);//for now
  double newlat = 39.0;
  double newlong= -77;
  String? idToRemove; // need for removeItemById
  Marker? curr_marker; // need for removeItemBy Id

  double closest_distance = double.infinity;
  //change this
  List<Marker> otherMarkers = [];
  //shaking
  late ShakeDetector _shakeDetector;


  @override
  void initState() {
    super.initState();
    //for locator
    _getCurrentLocation();
    Geolocator.getPositionStream().listen(
            (Position? position) {
          print(position == null ? 'Unknown' : '${position.latitude.toString()}, ${position.longitude.toString()}');
          newlat = position!.latitude;
          newlong = position!.longitude;
          _getCurrentLocation();
          _mapController.move(LatLng(newlat, newlong), 18);
          _findClosestMarker();
        });
    //for ShakeDetector
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: () {
        // Capture when shake is detected
        if (closest_distance <= 10) {
          Provider.of<StatsCounter>(context, listen: false).incrementTerpiezCounter();
          addCaught(idToRemove!, curr_marker!.point.latitude, curr_marker!.point.longitude);
          removeItemById(idToRemove!, curr_marker!.point.latitude, curr_marker!.point.longitude);
          widget.onCaptureSuccess();
          _showCaptureSuccessDialog(context, idToRemove!);
        }
      },
    );

  }

  //awaiting for geo to respond
  Future<void> _getCurrentLocation() async {
    //requesting
    try {
      //print("Requesting for permission");
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      //print("Fetching current position...");
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        newlat = position.latitude;
        newlong = position.longitude;
        //_currentPosition = LatLng(position.latitude, position.longitude);

        _mapController.move(LatLng(newlat, newlong), 18);
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }
  //find the closest marker to current location
  void _findClosestMarker() async {

    List<List<dynamic>> uncaughtMarkers = await convertUncaughtToMarkers();
    double curr_distance = double.infinity;

    //only 1 marker can exist
    otherMarkers.clear();


    for (var item in uncaughtMarkers) {
      double distance = Geolocator.distanceBetween(newlat, newlong, item[0].point.latitude, item[0].point.longitude);
      if(distance < curr_distance) {
        curr_distance = distance;
        curr_marker = item[0];
        idToRemove = item[1];
      }
    };
    closest_distance = curr_distance;
    otherMarkers.add(curr_marker!);

    //i dont need to call this again because my code auto refreshes

    /*now figure out how to use the current marker, to delete from unCaught
    then update it into a new thing called caught,
    (done) 1. make hold curr id global
    (done )2.delete from uncaught with id,
    3. add into caught (there could be mutiple of the same id)you want [id: [locations....]....]
    4. caught {id, locations, amount}
    5. i have to do LIST, dynamic page buildder, and stats preferences
     */
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Terpiez Found', style: TextStyle(fontSize: 40)),
              Spacer(),

              //flutter map container
              Container(
                height: 400,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    //marking intitial position
                    initialCenter: LatLng(newlat, newlong),
                    initialZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        //current marker location
                        Marker(
                          point: LatLng(newlat, newlong),
                          width: 80,
                          height: 80,
                          child: Icon(
                            Icons.arrow_downward,
                            size: 40.0,
                            color: Colors.blue,
                          ),
                        ),
                        ...otherMarkers // other markers inserted
                      ],
                    ),
                    //the radius circle
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(newlat, newlong),
                          color: Colors.blue.withOpacity(0.5),
                          radius: 10,
                          useRadiusInMeter: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Spacer(),
              Text('Closest Terpiez:', style: TextStyle(fontSize: 20)),
              Text('${closest_distance.toStringAsFixed(2)}', style: TextStyle(fontSize: 20)),
              //Text('Pos ${newlat} : ${newlong}', style: TextStyle(fontSize: 20)),


                  ElevatedButton(
                  //if curr location marker's distance is 10m to a terpiez, and user
                  //press button, icrement it
                  onPressed: () {
                  if(closest_distance <= 10) {
                  Provider.of<StatsCounter>(context, listen: false).incrementTerpiezCounter();
                  addCaught(idToRemove!, curr_marker!.point.latitude, curr_marker!.point.longitude);
                  removeItemById(idToRemove!, curr_marker!.point.latitude, curr_marker!.point.longitude);
                  widget.onCaptureSuccess();
                  _showCaptureSuccessDialog(context, idToRemove!);
                  }
                  },
                  child: Text('Capture the TERPIEZ'),
                  ),


            ],
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Terpiez Finder', style: TextStyle(fontSize: 20)),
              Spacer(),
              Row(
                children: [
                  //flutter map container
                  Container(
                    height: 200,
                    width: 420,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        //marking intitial position
                        initialCenter: LatLng(newlat, newlong),
                        initialZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: 'com.example.app',
                        ),
                        MarkerLayer(
                          markers: [
                            //current marker location
                            Marker(
                              point: LatLng(newlat, newlong),
                              width: 80,
                              height: 80,
                              child: Icon(
                                Icons.arrow_downward,
                                size: 40.0,
                                color: Colors.blue,
                              ),
                            ),
                            ...otherMarkers // other markers inserted
                          ],
                        ),
                        //the radius circle
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(newlat, newlong),
                              color: Colors.blue.withOpacity(0.5),
                              radius: 10,
                              useRadiusInMeter: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column (
                    children: [
                      Text('Closest Terpiez:', style: TextStyle(fontSize: 20)),
                      Text('${closest_distance}', style: TextStyle(fontSize: 20)),
                      Text('Pos ${newlat} : ${newlong}', style: TextStyle(fontSize: 20)),


                          ElevatedButton(
                          //if curr location marker's distance is 10m to a terpiez, and user
                          //press button, increment it
                          onPressed: () {
                          if(closest_distance <= 10) {
                          Provider.of<StatsCounter>(context, listen: false).incrementTerpiezCounter();
                          addCaught(idToRemove!, curr_marker!.point.latitude, curr_marker!.point.longitude);
                          removeItemById(idToRemove!, curr_marker!.point.latitude, curr_marker!.point.longitude);
                          widget.onCaptureSuccess();
                          _showCaptureSuccessDialog(context, idToRemove!);
                          }
                          },
                          child: Text('Capture the TERPIEZ'),
                          ),

                    ],
                  )
                ],
              ),
            ],
          );
        }
      },
    );
  }
}

class StatsCounter with ChangeNotifier {
  static const String _terpiezFound = 'terpiezFound';
  SharedPreferences? _prefs;// = await SharedPreferences.getInstance();
  int? _terpiezCounter; // = _prefs?.getInt(_terpiezFound);

  StatsCounter() {
    _initialize();
  }
  //initialize(
  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _terpiezCounter = _prefs?.getInt(_terpiezFound);

    if(_terpiezCounter == null) {
      _terpiezCounter = 0;
      await _prefs?.setInt(_terpiezFound, _terpiezCounter!);
    }
    notifyListeners();
  }



  int get terpiezCount => _terpiezCounter!;

  void incrementTerpiezCounter() {
    _terpiezCounter = _terpiezCounter! + 1;
    _prefs?.setInt(_terpiezFound, _terpiezCounter!);//save
    notifyListeners();
  }
}

//dialog capture box
void _showCaptureSuccessDialog(BuildContext context, String idToRemove) async {
  //image
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }
  File imageFile = File('${dir!.path}/image/$idToRemove.png');

  //terpiez info
  SharedPreferences? _prefs = await SharedPreferences.getInstance();
  var infoJson = _prefs?.getString('TerpiezInfo');

  if(infoJson == null) {
    print("in showCaptureSuccess, cannot find either caught json or infoJson");
    return;
  }
  var decodedInfo = jsonDecode(infoJson);
  var name = decodedInfo[idToRemove]['name'];

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Terpiez Captured!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            //image here
            Container(
              width: 100,
              height: 100,
              child: Image.file(imageFile, fit: BoxFit.contain),
            ),
            SizedBox(height: 10),
            //name here
            Text('You Caught $name'),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Exit'),
          ),
        ],
      );
    },
  );
}
