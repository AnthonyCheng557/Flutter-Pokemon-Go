
import 'findersPage.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';


import 'package:shared_preferences/shared_preferences.dart';


class DurationTracker {
  DateTime start;
  DateTime curr;

  DurationTracker({DateTime? Start})
      : start = Start ?? DateTime.now(),
        curr = DateTime.now();

  int get daysDifference => curr.difference(start).inDays;
}

class StatsPage extends StatefulWidget {
  @override
  _StatsPageState createState() => _StatsPageState();
}


class _StatsPageState extends State<StatsPage> {
  SharedPreferences? _prefs;

  //time
  DurationTracker tracker = DurationTracker();
  static const String _userStartYear = 'userYear';
  static const String _userStartMonth = 'userMonth';
  static const String _userStartDay = 'userDay';

  int? StartYear;
  int? StartMonth;
  int? StartDay;

  //uuid
  static const String _userID = 'userId';
  String? uuid;
  int? numFound;


  @override
  void initState() {
    super.initState();
    _initializeUserID();
  }

  Future<void> _initializeUserID() async {
    _prefs = await SharedPreferences.getInstance();

    uuid = _prefs?.getString(_userID);
    if (uuid == null) {
      uuid = Uuid().v1();
      await _prefs?.setString(_userID, uuid!);
    }



    StartYear = _prefs?.getInt(_userStartYear);
    StartMonth = _prefs?.getInt(_userStartMonth);
    StartDay = _prefs?.getInt(_userStartDay);
    if (StartYear == null || StartMonth == null || StartDay == null) {
      StartYear = tracker.curr.year;
      StartMonth = tracker.curr.month;
      StartDay = tracker.curr.day;

      await _prefs?.setInt(_userStartYear, StartYear!);
      await _prefs?.setInt(_userStartMonth, StartMonth!);
      await _prefs?.setInt(_userStartDay, StartDay!);
    }
    tracker = DurationTracker(Start: DateTime(StartYear!, StartMonth!, StartDay!));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('Statistics', style: TextStyle(fontSize: 40)),
      Align(
        alignment: Alignment.centerLeft,
        child: Consumer<StatsCounter>(
          builder: (context, StatsCounter, child) {
            return Text(
              '   Terpiez found: ${StatsCounter.terpiezCount}',
              // Access the count via the Consumer
              style: TextStyle(fontSize: 15),
            );
          },
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('   Days Active: ${tracker.daysDifference}',
            style: TextStyle(fontSize: 15)),
      ),
      Spacer(flex: 1),
      Align(
        alignment: Alignment.center,
        child: Text(
          '   User: ${uuid}',
          style: TextStyle(fontSize: 15),
        ),
      ),
      Spacer(flex: 2),
    ]);
  }
}

