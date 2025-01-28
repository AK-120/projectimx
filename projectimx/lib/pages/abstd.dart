import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AbsentStudentsPage extends StatelessWidget {
  final String selectedDepartment;
  final String selectedSemester;
  final DateTime selectedDate;

  AbsentStudentsPage({
    required this.selectedDepartment,
    required this.selectedSemester,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Absent Students'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Absent Students for ${DateFormat('d MMM yyyy').format(selectedDate)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Attendance Report Table Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Adm. No', style: TextStyle(color: Colors.black54)),
                Text('Name', style: TextStyle(color: Colors.black54)),
              ],
            ),
            SizedBox(height: 8),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('timestamp',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day)))
                    .where('timestamp',
                        isLessThan: Timestamp.fromDate(DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day + 1)))
                    .where('department', isEqualTo: selectedDepartment)
                    .where('semester', isEqualTo: selectedSemester)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final attendanceDocs = snapshot.data!.docs;

                  // Find all students who are not in the attendance records
                  return StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('user_type', isEqualTo: 'Student')
                        .where('department', isEqualTo: selectedDepartment)
                        .where('semester', isEqualTo: selectedSemester)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final allStudents = userSnapshot.data!.docs;
                      List<String> presentUserIds = [];
                      for (var doc in attendanceDocs) {
                        if (doc['user_type'] == 'Student') {
                          presentUserIds.add(doc['id']);
                        }
                      }

                      // Filter absent students
                      final absentStudents = allStudents.where((studentDoc) {
                        return !presentUserIds.contains(studentDoc['id']);
                      }).toList();

                      if (absentStudents.isEmpty) {
                        return Center(child: Text("No absent students for this date."));
                      }

                      return ListView.builder(
                        itemCount: absentStudents.length,
                        itemBuilder: (context, index) {
                          final student = absentStudents[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(student['id'] ?? 'N/A'),
                                Text(student['name'] ?? 'N/A'),
                              ],
                            ),
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
    );
  }
}
