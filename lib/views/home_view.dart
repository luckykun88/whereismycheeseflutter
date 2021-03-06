import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_map_trial/widgets/addCheeseDialog.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/user_location.dart';
import '../services/cheese_service.dart';
import '../widgets/cheeseInfoDialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong/latlong.dart'
    as lat; //function to help calculate distance between two geo-locations

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => MapSampleState();
}

class MapSampleState extends State<MyHomePage> {
  BitmapDescriptor pinLocationIcon;

  FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  var settingsAndroid;
  var settingsIOS;
  var initializationSettings;

  List<Marker> markerList = [];

  @override
  void initState() {
    super.initState();

    //Following code handles notifications
    settingsAndroid = AndroidInitializationSettings('cheese_logo');
    settingsIOS = IOSInitializationSettings(
        onDidReceiveLocalNotification: onDidReceiveLocalNotification);
    initializationSettings =
        InitializationSettings(settingsAndroid, settingsIOS);

    notifications.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    //Sets custom image for marker; in this case, cheese.
    BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5),
            'assets/icon/cheese64.png')
        .then((onValue) {
      pinLocationIcon = onValue;
    });
  }

  //notification message display for android
  Future onSelectNotification(String payload) async {
    if (payload != null) {
      print('Notification payload: $payload');
    }
    await showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: Text(
                  'There was a cheese near your location, now it has been removed'),
              actions: <Widget>[
                FlatButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Okay'))
              ],
            ));
  }

  //notification message display for IOS
  Future onDidReceiveLocalNotification(
      int id, String title, String body, String payload) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: Text(
                  'There was a cheese near your location, now it has been removed'),
              actions: <Widget>[
                FlatButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Okay'))
              ],
            ));
  }

  //function which displays notification on phone
  void showNotifications() async {
    await _demoNotification();
  }

  Future<void> _demoNotification() async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'channel ID', 'channel name', 'channel description',
        importance: Importance.Max,
        priority: Priority.High,
        ticker: 'test ticker');

    var iOSChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSChannelSpecifics);

    await notifications.show(
        0, 'Check me!', 'You are near a cheese', platformChannelSpecifics,
        payload: 'test');
  }

  Completer<GoogleMapController> _controller = Completer();

  final lat.Distance distance = new lat.Distance();

  @override
  Widget build(BuildContext context) {
    //provider for user location with latitude and longitude
    var userLocation = Provider.of<UserLocation>(context);

    //provider for cheese list
    final appState = Provider.of<CheeseModel>(context);

    //initial camera position set to user location
    CameraPosition _initialPosition = CameraPosition(
      target: LatLng(userLocation.latitude, userLocation.longitude),
      zoom: 15,
    );

    //Calculate distance between marker and user location using latitude and longitude
    double calculateDistance(latitude, longitude) {
      final double meter = distance(
          new lat.LatLng(userLocation.latitude, userLocation.longitude),
          new lat.LatLng(latitude, longitude));
      //return distances in meters
      return meter;
    }

    checkIfCloseToUserLocation() async {
      appState.cheese.forEach((element) {
        //for each marker in cheese instance, calculate distance between marker and user location and return distance
        double meter = calculateDistance(element.marker.position.latitude,
            element.marker.position.longitude);

        //check if distance is less or equal to 50 meters
        if (meter <= 50) {
          //check if this is a new marker
          if (element.isFirstTime) {
              return null;
          } else {
            //show notification
            showNotifications();
            //remove marker
              appState.remove(element.marker.markerId);
          }
        } else {
          //if marker distance from user is greater than 50 meteres and its a newly created marker, remove boolen to check as newly created marker
          element.isFirstTime = false;
        }
      });
    }

    checkIfCloseToUserLocation();

    //setting how the marker in Google Map will appear.
    Marker initialCheeseMarker(LatLng point) => Marker(
        markerId: MarkerId(point
            .toString()), //take point and convert it to string to make it the marker ID
        position: point,
        icon: pinLocationIcon,
        onTap: () {
          //when the marker is tapped it opens a dialog
          showDialog(
              context: context,
              builder: (BuildContext context) {
                //this is a dialog which contains the cheese message
                return CheeseInfoDialog(MarkerId(point.toString()),
                    appState.displayMessage(MarkerId(point.toString())));
              });
        });

    void _onCameraMove(CameraPosition position) {
      position = _initialPosition;
    }

    return new Scaffold(
      appBar: AppBar(
        title: Text('WhereIsMyCheese'),
        backgroundColor: Colors.orange[500],
      ),
      body: GoogleMap(
        //Google map background
        mapType: MapType.normal, //normal map type set
        myLocationButtonEnabled: true,
        onCameraMove: _onCameraMove,
        initialCameraPosition: _initialPosition,

        //returns all markers from cheese in a list, which then is displayed in the map
        markers: Set.from(appState.cheese
            .map((x) => initialCheeseMarker(x.marker.position))
            .toList()),

        //when map is created, this Google Map controller is run
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },

        //on long press on at any point of the Google map,
        //a dialog opens up and the user can enter the cheese message and add it to the list of cheese
        onLongPress: (LatLng point) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return CheeseDialog(point, initialCheeseMarker);
              });
        },
        myLocationEnabled: true,
        compassEnabled: true,
      ),
    );
  }
}
