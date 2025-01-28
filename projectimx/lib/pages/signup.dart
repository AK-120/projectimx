import 'package:flutter/material.dart';
import 'cameraS.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String id = '';
  String dept = 'Computer Engineering'; // Default department
  String userType = 'Student'; // Default user type
  String sem = 'Sem 1'; // Default semester
  File? _faceImage;
  List<double>? _faceEmbeddings;
  bool isLoading = false;

  Future<void> _openCamera() async {
    setState(() {
      isLoading = true;
    });

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CameraScreen()),
    );

    setState(() {
      isLoading = false;
    });

    if (result != null) {
      setState(() {
        _faceImage = result['image'];
        _faceEmbeddings = result['embeddings'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face detected successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face not detected! Please try again.')),
      );
    }
  }

  Future<void> _saveUserData() async {
    if (_faceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture an image with a face')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String imageUrl = '';
      if (_faceImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('$id.jpg');
        await ref.putFile(_faceImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Save user data to Firestore
      await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'id': id,
        'department': dept,
        'user_type': userType,
        'semester': sem,
        'photo_url': imageUrl,
        'embedding': _faceEmbeddings,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User Registered Successfully')),
      );

      _formKey.currentState?.reset();
      setState(() {
        name = '';
        id = '';
        dept = 'Computer Engineering';
        userType = 'Student';
        sem = 'Sem 1';
        _faceImage = null;
        _faceEmbeddings = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering user: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'Name'),
                  onSaved: (value) => name = value!,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: userType,
                  decoration: InputDecoration(labelText: 'User Type'),
                  items: ['Student', 'Faculty'].map((String userType) {
                    return DropdownMenuItem<String>(
                      value: userType,
                      child: Text(userType),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      userType = value!;
                      if (userType == 'Faculty') {
                        sem = ''; // Clear semester if Faculty is selected
                      } else {
                        sem = 'Sem 1'; // Reset semester for Student
                      }
                    });
                  },
                ),
                if (userType == 'Student')
                  DropdownButtonFormField<String>(
                    value: sem,
                    decoration: InputDecoration(labelText: 'Semester'),
                    items: [
                      'Sem 1',
                      'Sem 2',
                      'Sem 3',
                      'Sem 4',
                      'Sem 5',
                      'Sem 6',
                    ].map((String sem) {
                      return DropdownMenuItem<String>(
                        value: sem,
                        child: Text(sem),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        sem = value!;
                      });
                    },
                    validator: (value) {
                      if (userType == 'Student' &&
                          (value == null || value.isEmpty)) {
                        return 'Please select your semester';
                      }
                      return null;
                    },
                  ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: userType == 'Faculty' ? 'Fac ID' : 'Adm No',
                  ),
                  onSaved: (value) => id = value!,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your ${userType == 'Faculty' ? 'Fac ID' : 'Adm No'}';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: dept,
                  decoration: InputDecoration(labelText: 'Department'),
                  items: [
                    'Computer Engineering',
                    'Electronics Engineering',
                    'Printing Technology',
                  ].map((String department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      dept = value!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your department';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                _faceImage == null
                    ? ElevatedButton(
                        onPressed: _openCamera,
                        child: Text('Capture Face'),
                      )
                    : Image.file(
                        _faceImage!,
                        height: 100,
                        width: 100,
                      ),
                SizedBox(height: 20),
                isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _formKey.currentState?.save();
                            _saveUserData();
                          }
                        },
                        child: Text('Sign Up'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
