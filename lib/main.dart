import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dataBase.dart';
import 'findersPage.dart';
import 'statsPage.dart';
import 'credentialPrompt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';


late FragmentProgram fragmentProgram;
SharedPreferences? _prefs;


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  fragmentProgram = await FragmentProgram.fromAsset('my_shader.frag');
  //
  //await storage.deleteAll();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => StatsCounter()),
        ChangeNotifierProvider(create: (context) => RefreshController()),
      ],
      child: MaterialApp(
        home: const PromptWrapper(
          child: MyApp(),
        ),
      ),
    ),
  );
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Terpiez'),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final refreshController = Provider.of<RefreshController>(context, listen: false);
    //clearPref();
    connectToRedisDataBase(context);
    getUncaught_getInfo();

    //listThumbnail();
    //listPages();


    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(
            title,
            textAlign: TextAlign.left,
          ),
          bottom: TabBar(tabs: [
            Tab(
              icon: Icon(Icons.query_stats),
              text: 'Stats',
            ),
            Tab(icon: Icon(Icons.search), text: 'Finder'),
            Tab(icon: Icon(Icons.list), text: 'List')
          ]),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              //stats Page
              Tab(
                child: StatsPage(),
              ),
              //finders Page
              Tab(
                child: FinderPage(
                  onCaptureSuccess: () {
                    Provider.of<RefreshController>(context, listen: false).refresh();
                  },
                ),
              ),
              //list Page
              Tab(
                child: Consumer<RefreshController>( //consume rebuild
                  builder: (context, refreshController, child) {
                    return FutureBuilder<List<Widget>>(
                      future: refreshController.pagesFuture ?? listPages(),
                      builder: (context, pagesSnapshot) {
                        return FutureBuilder<int>(
                          future: caughtSize(),
                          builder: (context, sizeSnapshot) {
                            return FutureBuilder<List<String>>(
                              future: nameList(),
                              builder: (context, namesSnapshot) {
                                return FutureBuilder<List<File>>(
                                  future: listThumbnail(),
                                  builder: (context, thumbnailsSnapshot) {
                                    return ListView.builder(
                                      itemCount: sizeSnapshot.data ?? 0,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          title: Text(namesSnapshot.data?[index] ?? 'Unknown'),
                                          leading: Hero(
                                            tag: namesSnapshot.data?[index] ?? 'default',
                                            child: SizedBox(
                                              width: 50.0,
                                              height: 50.0,
                                              child: thumbnailsSnapshot.data?[index] != null
                                                  ? Image.file(
                                                thumbnailsSnapshot.data![index],
                                                fit: BoxFit.cover,
                                              )
                                                  : const Placeholder(),
                                            ),
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => pagesSnapshot.data![index],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//the pages
class BugPage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Bug'),
          centerTitle: false,
        ),
        body: Center(
          child: Column(children: [
            Hero(
              tag: 'Bug',
              child: Icon(
                Icons.bug_report,
                size: 200,
              ),
            ),
            Text('Bugs', style: TextStyle(fontSize: 20))
          ]),
        ));
  }
}




class myPage extends StatefulWidget {
  final String id;
  final String name;
  final File image;
  final List<Marker> otherMarkers;
  final List<int> stats;
  final String description;

  const myPage({Key? key,
    required this.id,
    required this.name,
    required this.image,
    required this.otherMarkers,
    required this.stats,
    required this.description,

  }) : super(key: key);

  @override
  _myPageState createState() => _myPageState();
}

class _myPageState extends State<myPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double uTime = 0; //initialize uTime
  final MapController _mapController = MapController();
  double lat = 38.99;
  double long= -76.93;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 100),
    )..repeat();

    _controller.addListener(() {
      setState(() {
        uTime = _controller.value * 100; //scale utime
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        centerTitle: false,
      ),
      body: Center(
        child: Stack(
          children: [CustomPaint(
            painter: MyPainter(
              color: Colors.orange,
              shader: fragmentProgram.fragmentShader(),
              uTime: uTime,
            ),
            size: Size.infinite,
          ),
            Center(
                child: OrientationBuilder(
                    builder: (context, orientation) {
                      if (orientation == Orientation.portrait) {
                        return Column(
                          children: [
                            SizedBox(height: 20.0),
                            Hero(
                              tag: 'Plane',
                              child: SizedBox(
                                width: 250.0,
                                height: 250.0,
                                child: Image.file(widget.image),
                              ),
                            ),
                            Text(widget.name, style: TextStyle(fontSize: 20)),
                            //give map height
                            SizedBox(
                              height: 200,
                              width: 390,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        initialCenter: LatLng(lat, long),
                                        initialZoom: 13,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                          userAgentPackageName: 'com.example.app',
                                        ),
                                        MarkerLayer(
                                          markers: widget.otherMarkers,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    child: Column(
                                      children: [
                                        Spacer(),
                                        Text("Avuncularity ${widget.stats[0]}", style: TextStyle(fontSize: 20)),
                                        Text('Destrucity ${widget.stats[1]}', style: TextStyle(fontSize: 20)),
                                        Text("Panache ${widget.stats[2]}", style: TextStyle(fontSize: 20)),
                                        Text("Spicinesss ${widget.stats[3]}", style: TextStyle(fontSize: 20)),
                                        Spacer(),
                                      ],

                                    ),

                                  ),
                                ],
                              ),

                            ),
                            Text("${widget.description}", style: TextStyle(fontSize: 16)),
                          ],

                        );

                      }else {
                        return Column(
                          children: [
                            //image, stats
                            Row(
                              children: [
                                SizedBox(height: 20.0),
                                Hero(
                                  tag: 'Plane',
                                  child: SizedBox(
                                    width: 200.0,
                                    height: 200.0,
                                    child: Image.file(widget.image),
                                  ),
                                ),
                                SizedBox(width: 20.0),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Avuncularity ${widget.stats[0]}", style: TextStyle(fontSize: 20)),
                                    Text('Destrucity ${widget.stats[1]}', style: TextStyle(fontSize: 20)),
                                    Text("Panache ${widget.stats[2]}", style: TextStyle(fontSize: 20)),
                                    Text("Spicinesss ${widget.stats[3]}", style: TextStyle(fontSize: 20)),
                                  ],
                                ),
                                SizedBox(width: 10.0),
                                //HERE
                                Container(
                                  height: 200,
                                  width: 450,
                                  child: FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: LatLng(lat, long),
                                      initialZoom: 13,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                        userAgentPackageName: 'com.example.app',
                                      ),
                                      MarkerLayer(
                                        markers: widget.otherMarkers,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            //map, and descritpion
                            SizedBox(width: 20.0),
                            Text("${widget.description}", style: TextStyle(fontSize: 16)),
                          ],
                        );
                      };
                    })
            ),
          ],
        ),
      ),
    );
  }
}

class MyPainter extends CustomPainter {
  MyPainter({required this.color, required this.shader, required this.uTime});

  final Color color;
  final FragmentShader shader;
  final double uTime;

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, color.red.toDouble());
    shader.setFloat(3, color.green.toDouble());
    shader.setFloat(4, color.blue.toDouble());
    shader.setFloat(5, color.alpha.toDouble());
    shader.setFloat(6, uTime);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(MyPainter oldDelegate) =>
      color != oldDelegate || uTime != oldDelegate.uTime;
}


//list of names
Future<List<String>> nameList() async {
  _prefs = await SharedPreferences.getInstance();
  //caught terpiez
  var caughtJson = _prefs?.getString('caughtTerpiez');

  //terpiez info
  var infoJson = _prefs?.getString('TerpiezInfo');

  if(caughtJson == null || infoJson == null) {
    print("in create nameList(), cannot find either caught json or infoJson");
    return [];
  }
  //decode
  var decodedCaught = jsonDecode(caughtJson);
  var decodedInfo = jsonDecode(infoJson);

  List<String> terpiezName = [];

  for (String caughtkey in decodedCaught.keys) {
    for (String infoKey in decodedInfo.keys) {
      if(caughtkey == infoKey) {
        terpiezName.add(decodedInfo[infoKey]['name'].toString());
      }
    }
  }
  return terpiezName;
}

//return size
Future<int> caughtSize() async {
  _prefs = await SharedPreferences.getInstance();
  //caught terpiez
  var caughtJson = _prefs?.getString('caughtTerpiez');

  if(caughtJson == null) {
    print("in create caughtSize(), cannot find caught json");
    return 0;  // Return 0 instead of empty return
  }

  var decodedCaught = jsonDecode(caughtJson);
  return decodedCaught.length;
}

//return icon
Future<List<File>> listThumbnail() async {
  _prefs = await SharedPreferences.getInstance();
  Directory? dir;

  try {
    dir = await getDownloadsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }

  if(dir == null) {
    print('dir does not exist');
    return [];
  }


  //caught terpiez
  var caughtJson = _prefs?.getString('caughtTerpiez');
  var decodedCaught = jsonDecode(caughtJson!);


  List<File> fileList = [];
  for(String key in decodedCaught.keys){
    File thumbnailFile = File('${dir.path}/thumbnail/$key.png');
    fileList.add(thumbnailFile);
  }

  return fileList;

}

Future<List<Widget>> listPages() async {
  _prefs = await SharedPreferences.getInstance();
  //caught
  var caughtJson = _prefs?.getString('caughtTerpiez');
  var terpiezInfo = _prefs?.getString('TerpiezInfo');

  if(terpiezInfo == null || caughtJson == null)  {
    return [];
  }
  //info
  var decodedInfo = jsonDecode(terpiezInfo!);
  var decodedCaught = jsonDecode(caughtJson!);

  if(decodedInfo == null || decodedCaught == null)  {
    return [];
  }

  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }


  //now make the markers

  List<Widget> myPages = [];
  for(String key in decodedCaught.keys){

    //get the locations for this key
    var locationJson = decodedCaught[key];
    var latList = locationJson['latList'];
    var longList = locationJson['longList'];
    List<Marker> markerList = [];
    for(int i = 0; i < latList.length; i++) {
      Marker curr = Marker(
        point: LatLng(latList[i], longList[i]),
        width: 80,
        height: 80,
        child: Icon(
          Icons.arrow_downward,
          size: 40.0,
          color: Colors.red,
        ),
      );
      markerList.add(curr);
    }
    //images
    File imageFile = File('${dir!.path}/image/$key.png');
    //name
    var name = decodedInfo[key]['name'];

    //stats
    List<int> stats = [];
    stats.add(decodedInfo[key]['stats']['Avuncularity']);
    stats.add(decodedInfo[key]['stats']['Destrucity']);
    stats.add(decodedInfo[key]['stats']['Panache']);
    stats.add(decodedInfo[key]['stats']['Spiciness']);


    //description
    String description = decodedInfo[key]['description'];

    //make pages
    myPages.add(myPage(id: key, name:name, image: imageFile, otherMarkers: markerList, stats: stats, description: description));
  }

  return myPages;

}

class RefreshController with ChangeNotifier {
  Future<List<Widget>>? pagesFuture;

  void refresh() {
    pagesFuture = listPages();
    notifyListeners();
  }
}




