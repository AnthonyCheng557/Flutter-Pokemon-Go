


import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'findersPage.dart';


import 'main.dart';

class NotificationService {
  //call instace for FlutterNotficiationPluggin()
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


  static Future<void> onDidReceiveNotification(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;

    MyApp.navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (context) => DefaultTabController(
          length: 3,
          child: HomePage(title: 'Terpiez', initialTabIndex: 1),
        ),
      ),
    ).then((_) {
      //fail
      //Navigator.pushNamed(MyApp.navigatorKey.currentState!.context, '/home/tab2');
    });

  }
  //initilization notfication plugin
  static Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings("@mipmap/my_custom");
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );
    //plugin with specific settings
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotification,
        onDidReceiveBackgroundNotificationResponse: onDidReceiveNotification,
    );

    //request persmsion from android
    await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.requestExactAlarmsPermission();
  }

  //Show an instant notification
  static Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'instant_notification_channel',
      'Instant Notifications',
      channelDescription: 'This channel is used for instant notifications',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: false,

    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }
}

