//we ar using redis dataBase here
import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:redis/redis.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

/*current keys
unCaughtTerpiez -> list of (lat,lon, and id)
uaughtTerpiez -> list of (lat,lon, and id)
TerpiezInfo -> list of {id, info {name, description, thumbnail, image, stat {A, D, P, S}}}
*/
//prefs
SharedPreferences? _prefs;
String? username;
String? password;

bool isConnected = false;

//redis connection
final redisConnection = RedisConnection();
var _command;

Future<void> connectToRedisDataBase(BuildContext context) async {
  int count = 0;
  //secure storage
  final storage = const FlutterSecureStorage();

  //get credentials
  username = await storage.read(key: 'username');
  password = await storage.read(key: 'password');

  if (username == null || password == null) {
    print("Username and/or password is missing from secure storage.");
    return;
  }
  //continousely run
  while (true) {
    try {
      _command = await redisConnection.connect('cmsc436-0101-redis.cs.umd.edu', 6380).timeout(Duration(seconds: 9));
      await _command.send_object(['AUTH', username, password]).timeout(Duration(seconds: 9));
      print("Connected successfully!");
      isConnected = true;

      //snack bar if prev connection is restored
      if(isConnected && count == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Restored'),
            duration: Duration(seconds: 3),
          ),
        );

      }
      //two purpose,
      // count=0 to fail message pops up fater success message
      // count=1 so connect lost always runs after first succesful connections
      count = 0;

    } catch (e) {
      print("Failed to connect to Redis");
      if(isConnected) {
        isConnected = false;
        count = 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection Lost'),
            duration: Duration(seconds: 3),
          ),
        );

      }
    }
    await Future.delayed(Duration(seconds: 10));
  }
}



//essentially get all unCaughtTerpiez
//if sharedPreference does not have key get a new database
//if sharedPreference does have the key, continue constructing the list
Future<void> getUncaught_getInfo() async {

  _prefs = await SharedPreferences.getInstance();

  Directory? dir;

  //Key 'unCaughtTerpiez by using locations'
  var unCaughtJson = _prefs?.getString('unCaughtTerpiez');

  if (unCaughtJson == null) {
    //if there is nothing then this is the first time we opens the dataBase
    //then we access dataBase to get location
    print('unCaughtTerpiez does not exist in shared_preference');
    var result = await _command.send_object(['JSON.GET', 'locations']);
    await _prefs?.setString('unCaughtTerpiez', result);
    //Delete later
    //print(result);

  } else {
    //if there is something then do nothing
    print('unCaughtTerpiez exist in shared_preference');
  }

  //key TerpiezInfo
  var InfoJson = _prefs?.getString('TerpiezInfo');
  if (InfoJson == null) {
    //if there is nothing then this is the first time we opens the dataBase
    //then we access dataBase to get location
    print('TerpiezInfo does not exist in shared_preference');
    var result = await _command.send_object(['JSON.GET', 'terpiez']);
    await _prefs?.setString('TerpiezInfo', result);
  } else {
    //if there is something then do nothing
    print('TerpiezInfo exist in shared_preference');
  }

  //now load the thumnail and images in directories
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }

  final imageDir = Directory('${dir!.path}/image');
  final thumbnailDir = Directory('${dir!.path}/thumbnail');
  final jsonDir = Directory('${dir!.path}/json');

  if (!imageDir.existsSync()) {
    await imageDir.create(recursive: true);
  }

  if (!thumbnailDir.existsSync()) {
    await thumbnailDir.create(recursive: true);
  }

  if (!jsonDir.existsSync()) {
    await jsonDir.create(recursive: true);
  }



  var decodedInfo = jsonDecode(InfoJson!);
  for(String key in decodedInfo.keys) {
    try {
      final decoder = base64.decoder;
      //thumbnail
      var thumbnailKey = await _command.send_object(['JSON.GET', 'terpiez', '${key}.thumbnail']);
      var cleanedKey = thumbnailKey.replaceAll('"', '');
      final thumbnailResult = await _command.send_object(['JSON.GET', 'images', cleanedKey]);
      File thumbnailFile = File('${dir.path}/thumbnail/$key.png');
      final dataString = thumbnailResult as String;
      final thumbnailData = decoder.convert(dataString, 1, dataString.length - 1);
      await thumbnailFile.writeAsBytes(thumbnailData);

      //images
      var imagesKey = await _command.send_object(['JSON.GET', 'terpiez', '${key}.image']);
      cleanedKey = imagesKey.replaceAll('"', '');
      final imageResult = await _command.send_object(['JSON.GET', 'images', cleanedKey]);
      File imageFile = File('${dir.path}/image/$key.png');
      final dataString2 = imageResult as String;
      final imageData = decoder.convert(dataString2, 1, dataString2.length - 1);
      await imageFile.writeAsBytes(imageData);

      //json for local
      //pt 1 get uid
      //HAVE TO FIGURE OUT
      var uid = _prefs?.getString('userId');
      var caughtJson = _prefs?.getString('caughtTerpiez');
      print(caughtJson);
      File jsonFile = File('${dir.path}/json/$uid.json');
      await jsonFile.writeAsString(caughtJson!);

      File json = File('${dir!.path}/json/$uid');

      print(json);

    } catch (e) {
      print("error");
      print(e);
    }
  }
}

//Function that takes unCaught, and make into Markers
Future<List<List<dynamic>>> convertUncaughtToMarkers() async {
  double lat;
  double lon;
  String id;
  List<List<dynamic>> uncaughtTerpiezMarkers = [];
  Marker curr;

  var uncaught = _prefs?.getString('unCaughtTerpiez');
  var decoded = jsonDecode(uncaught.toString());


  for (var item in decoded) {
    lat = item['lat'];
    lon = item['lon'];
    id = item['id'];

    curr = Marker(
      point: LatLng(lat, lon),
      width: 80,
      height: 80,
      child: Icon(
        Icons.arrow_downward,
        size: 40.0,
        color: Colors.red,
      ),
    );
    uncaughtTerpiezMarkers.add([curr, id]);
  }
  return uncaughtTerpiezMarkers;
}

Future<void> removeItemById(String idToRemove, double lat, double long) async {
  var unCaughtJson = _prefs?.getString('unCaughtTerpiez');
  if(unCaughtJson == null) {
    print("removeItemByID Json missing");
    //nothing to do
    return;
  }
  print(unCaughtJson);
  var decoded = jsonDecode(unCaughtJson!);

  for(int i = 0; i < decoded!.length; i++) {
    if(decoded[i]['id'] == idToRemove && decoded[i]['lat'] == lat && decoded[i]['lon'] == long) {
      decoded.removeAt(i);
      var encoded = jsonEncode(decoded);
      await _prefs?.setString('unCaughtTerpiez', encoded);
      print("deleted1 $idToRemove and length ${decoded!.length}: ${lat}:${long}");
      return;
    }
  }
  print("cannot1 find id to remove");
}
//key is captured

Future<void> addCaught(String idToAdd, double lat, double long) async {
  _prefs = await SharedPreferences.getInstance();

  //worry about caught list
  var caughtJson = _prefs?.getString('caughtTerpiez');
  var decodedCaught;

  if(caughtJson == null) {
    print("Caught does not exist, create new");
    decodedCaught = <String, Map<String, dynamic>>{};
  } else {
    print("Caught does exist,... decoding");
    decodedCaught = jsonDecode(caughtJson);
  }
  //worry about uncaught list
  var unCaughtJson = _prefs?.getString('unCaughtTerpiez');
  if(unCaughtJson == null) {
    print("unCaught json missing, returning");
    return;
  }
  var decodedUnCaught = jsonDecode(unCaughtJson!);
  print(decodedUnCaught);
  for(int i = 0; i < decodedUnCaught!.length; i++) {

    if(decodedUnCaught[i]['id'] == idToAdd) {
      var typeCaught = decodedCaught[idToAdd];
      if(typeCaught == null) {
        //if null then give them id -> [list(lat), list(long), count]
        decodedCaught[idToAdd] = <String, dynamic>{};
        decodedCaught[idToAdd]['latList'] = [];
        decodedCaught[idToAdd]['latList'].add(lat);
        decodedCaught[idToAdd]['longList'] = [];
        decodedCaught[idToAdd]['longList'].add(long);
        decodedCaught[idToAdd]['count'] = 1;
      } else {
        //if it does exist great
        decodedCaught[idToAdd]['latList'].add(lat);
        decodedCaught[idToAdd]['longList'].add(long);
        decodedCaught[idToAdd]['count'] = decodedCaught[idToAdd]['count'] + 1;
      }

      var encoded = jsonEncode(decodedCaught);
      await _prefs?.setString('caughtTerpiez', encoded);
      //print("caught $idToAdd lat: ${decodedCaught[idToAdd]['latList'].toString()} long: ${decodedCaught[idToAdd]['longList'].toString()} count ${decodedCaught[idToAdd]['count'].toString()}");
      //now we open and close again after every capture
      var id = await _prefs?.getString('userId');
      await _command.send_object(['JSON.SET', username, id, encoded]);

      return;
    }
  }
  print("cannot find id to add");
}


//for testing
Future<void> clearPref() async {
  _prefs?.clear();
}







