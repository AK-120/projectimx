import 'package:flutter/material.dart';

class AddUserScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add User'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          children: [
            Icon(Icons.person, size: 100),  // Replace with your icon
            Text('Student', style: TextStyle(fontSize: 24)),
            Text('Faculty', style: TextStyle(fontSize: 24)),
            ElevatedButton(onPressed: () {}, child: Text('Login')),  // Example button
          ],
        ),
      ),
    );
  }
}
