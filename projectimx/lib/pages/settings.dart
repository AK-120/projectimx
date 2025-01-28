import 'package:flutter/material.dart';
import 'holi.dart';
import 'timeRes.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.send, color: Colors.blue),
            title: Text('Send Daily Report'),
            onTap: () {
              // Navigate to Send Daily Report Page
            },
          ),
          ListTile(
            leading: Icon(Icons.calendar_today, color: Colors.blue),
            title: Text('Academic Calendar'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onTap: () {
              // Navigate to Academic Calendar Page
            },
          ),
          ListTile(
            leading: Icon(Icons.help, color: Colors.blue),
            title: Text('Help'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onTap: () {
              // Navigate to Help Page
            },
          ),
          ListTile(
            leading: Icon(Icons.info, color: Colors.blue),
            title: Text('About Us'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onTap: () {
              // Navigate to About Us Page
            },
          ),
          ListTile(
            leading: Icon(Icons.star, color: Colors.blue),
            title: Text('Review'),
            onTap: () {
              // Navigate to Review Page
            },
          ),
          ListTile(
            leading: Icon(Icons.beach_access, color: Colors.blue),
            title: Text('Holidays'),
            onTap: () {
              // Navigate to the HolidayPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HolidayPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.access_alarms, color: Colors.blue),
            title: Text('Time Restriction'),
            onTap: () {
              // Navigate to the HolidayPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TimeRestrictionPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
