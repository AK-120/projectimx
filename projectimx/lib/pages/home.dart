import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting time and date
import 'package:projectimx/pages/scaner.dart'; // Import the scan result screen
import 'package:projectimx/pages/botnav.dart';

class HomeScreen extends StatefulWidget {
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<HomeScreen> {
  String _timeString = '';
  String _dateString = '';
  bool isHoliday = false; // To track if it's a holiday
  String holidayName = ''; // To store the holiday name
  DateTime _selectedDate = DateTime.now(); // Default to today
  Map<String, String> _timeRestrictions = {}; // To store time restrictions

  @override
  void initState() {
    super.initState();
    _updateTime();
    Timer.periodic(Duration(seconds: 1), (Timer t) => _updateTime());
    _fetchTimeRestrictions();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = DateFormat('h:mm a').format(now);
    final String formattedDate = DateFormat('EEE, d MMMM').format(now);
    setState(() {
      _timeString = formattedTime;
      _dateString = formattedDate;
    });
  }

  Future<void> _fetchTimeRestrictions() async {
    final String currentDay = DateFormat('EEEE').format(DateTime.now());

    if (['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
        .contains(currentDay)) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('time_restrictions')
            .doc(currentDay)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            _timeRestrictions = Map<String, String>.from(docSnapshot.data()!);
          });
        } else {
          print("No time restrictions found for $currentDay");
        }
      } catch (e) {
        print("Error fetching time restrictions: $e");
      }
    } else {
      print("Today is not a working day (Mon-Fri).");
    }
  }

  Future<void> _checkIfHoliday() async {
    try {
      String formattedDate =
          _selectedDate.toIso8601String().split('T')[0] + 'T00:00:00.000';

      final holidaySnapshot = await FirebaseFirestore.instance
          .collection('holidays')
          .where('date', isEqualTo: formattedDate)
          .get();

      if (holidaySnapshot.docs.isNotEmpty) {
        setState(() {
          isHoliday = true;
          holidayName = holidaySnapshot.docs.first['name'] ?? 'Unknown Holiday';
        });
      } else {
        setState(() {
          isHoliday = false;
          holidayName = '';
        });
      }
    } catch (e) {
      print("Error checking for holiday: $e");
    }
  }

  bool _isTimeWithinRange() {
    final now = DateTime.now();
    final formattedTime = DateFormat('h:mm a').format(now);

    String checkInStart = _timeRestrictions['morning_check_in_start'] ?? '';
    String checkInEnd = _timeRestrictions['morning_check_in_end'] ?? '';
    String checkOutStart = _timeRestrictions['morning_check_out_start'] ?? '';
    String checkOutEnd = _timeRestrictions['morning_check_out_end'] ?? '';

    if (formattedTime.compareTo(checkInStart) >= 0 &&
        formattedTime.compareTo(checkInEnd) <= 0) {
      return true; // Morning check-in allowed
    }

    if (formattedTime.compareTo(checkOutStart) >= 0 &&
        formattedTime.compareTo(checkOutEnd) <= 0) {
      return true; // Morning check-out allowed
    }

    return false; // Not within time limits
  }

  void _handleScan(BuildContext context) async {
    await _checkIfHoliday(); // Check for holidays before proceeding

    if (isHoliday) {
      // Show a popup if it's a holiday
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Holiday Alert'),
            content: Text('Today is $holidayName. Scanning is not allowed.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      // Check if current time is within allowed check-in/check-out range
      if (_isTimeWithinRange()) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScannerScreen()),
        );
      } else {
        // Show an alert if the time is not within range
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Time Alert'),
              content: Text('Scanning is not allowed at this time.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _handleSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BottomNav()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set the background color
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dynamic Time Display
            Text(
              _timeString, // Dynamic time
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8), // Space between time and date

            // Dynamic Date Display
            Text(
              _dateString, // Dynamic date
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 40), // Space before scan icon

            // Camera Icon and Scan Text
            GestureDetector(
              onTap: () => _handleScan(context),
              child: Column(
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 100,
                    color: Colors.grey[400], // Light grey color for icon
                  ),
                  SizedBox(height: 8), // Space between icon and text
                  Text(
                    'SCAN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            Spacer(), // Push the settings icon to the bottom

            // Settings Icon
            Padding(
              padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
              child: Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () =>
                      _handleSettings(context), // Handle settings action
                  child: Icon(
                    Icons.settings,
                    size: 32,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
