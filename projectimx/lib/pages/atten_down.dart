import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class AttendanceReportPage extends StatefulWidget {
  @override
  _AttendanceReportPageState createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _workingDaysController = TextEditingController();
  String _selectedDepartment = "Computer Engineering";
  String _selectedSemester = "Sem 6";
  DateTime selectedMonth = DateTime.now();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allAttendance = [];
  List<Map<String, dynamic>> _attendanceData = [];
  List<String> holidayList = []; // Populate this list with Firebase data.

  @override
  void initState() {
    super.initState();
    _fetchInitialData(); // Load all data at the start.
  }

  Future<void> _fetchInitialData() async {
    try {
      // Fetch all users
      final userSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      _allUsers = userSnapshot.docs.map((doc) => doc.data()).toList();

      // Fetch all attendance records
      final attendanceSnapshot =
          await FirebaseFirestore.instance.collection('attendance').get();
      _allAttendance =
          attendanceSnapshot.docs.map((doc) => doc.data()).toList();

      // Fetch holidays (optional)
      final holidaySnapshot =
          await FirebaseFirestore.instance.collection('holidays').get();
      holidayList =
          holidaySnapshot.docs.map((doc) => doc['date'] as String).toList();

      setState(() {});
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  List<String> _getWorkingDays(DateTime month) {
    DateTime firstDayOfMonth = DateTime(month.year, month.month, 1);
    DateTime lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    List<String> workingDays = [];
    DateTime currentDate = firstDayOfMonth;

    while (currentDate.isBefore(lastDayOfMonth) ||
        currentDate.isAtSameMomentAs(lastDayOfMonth)) {
      if (currentDate.weekday != DateTime.saturday &&
          currentDate.weekday != DateTime.sunday &&
          !holidayList.contains(DateFormat('yyyy-MM-dd').format(currentDate))) {
        workingDays.add(DateFormat('yyyy-MM-dd').format(currentDate));
      }
      currentDate = currentDate.add(Duration(days: 1));
    }

    return workingDays;
  }

  Future<void> _calculateAttendance() async {
    if (_allUsers.isEmpty || _allAttendance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No data available.")),
      );
      return;
    }

    final workingDays = _getWorkingDays(selectedMonth);
    final workingDaysCount = workingDays.length;

    List<Map<String, dynamic>> attendanceData = [];

    for (var user in _allUsers) {
      if (user['department'] == _selectedDepartment &&
          user['semester'] == _selectedSemester) {
        final userId = user['id'];
        final userName = user['name'];

        // Filter attendance for this user and the selected month
        final userAttendance = _allAttendance.where((record) {
          return record['id'] == userId && workingDays.contains(record['date']);
        }).toList();

        final daysPresent = userAttendance.length;
        final percentage =
            workingDaysCount > 0 ? (daysPresent / workingDaysCount) * 100 : 0;

        attendanceData.add({
          'id': userId,
          'name': userName,
          'monthAttendance': daysPresent,
          'totalWorkingDays': workingDaysCount,
          'attendancePercentage': percentage.toStringAsFixed(2),
        });
        Future<void> _calculateAttendance() async {
          if (_allUsers.isEmpty || _allAttendance.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No data available.")),
            );
            return;
          }

          // Get working days for the selected month
          final workingDays = _getWorkingDays(selectedMonth);
          final workingDaysCount = workingDays.length;

          if (workingDaysCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text("No working days found for the selected month.")),
            );
            return;
          }

          List<Map<String, dynamic>> attendanceData = [];

          for (var user in _allUsers) {
            if (user['department'] == _selectedDepartment &&
                user['semester'] == _selectedSemester) {
              final userId = user['id'];
              final userName = user['name'];

              // Filter attendance records for this user and the selected month
              final userAttendance = _allAttendance.where((record) {
                // Extract and validate the `date` field
                final recordDateString = record['date'] ?? '';
                return record['id'] == userId &&
                    workingDays.contains(recordDateString);
              }).toList();

              // Calculate attendance stats
              final daysPresent = userAttendance.length;
              final attendancePercentage = workingDaysCount > 0
                  ? (daysPresent / workingDaysCount) * 100
                  : 0;

              attendanceData.add({
                'id': userId,
                'name': userName,
                'monthAttendance': daysPresent,
                'totalWorkingDays': workingDaysCount,
                'attendancePercentage': attendancePercentage.toStringAsFixed(2),
              });
            }
          }

          setState(() {
            _attendanceData = attendanceData;
          });

          // Debugging: Print calculated attendance data
          print('Attendance Data: $_attendanceData');
        }
      }
    }

    setState(() {
      _attendanceData = attendanceData;
    });
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(
        children: [
          pw.Text(
              'Attendance Report for $_selectedDepartment ($_selectedSemester)'),
          pw.Table.fromTextArray(
            headers: [
              'Name',
              'ID',
              'Days Present',
              'Total Working Days',
              'Attendance Percentage'
            ],
            data: _attendanceData.map((data) {
              return [
                data['name'],
                data['id'],
                data['monthAttendance'],
                data['totalWorkingDays'],
                data['attendancePercentage'],
              ];
            }).toList(),
          ),
        ],
      );
    }));

    final outputDir = await getExternalStorageDirectory();
    final file = File("${outputDir!.path}/attendance_report.pdf");
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF saved to ${file.path}")),
    );
  }

  Future<void> pickMonth(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(selectedMonth.year, selectedMonth.month, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      selectableDayPredicate: (day) =>
          day.day == 1 && day.isBefore(DateTime.now().add(Duration(days: 1))),
    );

    if (pickedDate != null) {
      setState(() {
        selectedMonth = DateTime(pickedDate.year, pickedDate.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => pickMonth(context),
              child: Text(
                'Select Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}',
              ),
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedDepartment,
              items: [
                'Computer Engineering',
                'Electronics Engineering',
                'Printing Technology'
              ]
                  .map((dept) => DropdownMenuItem(
                        value: dept,
                        child: Text(dept),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDepartment = value!;
                });
              },
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedSemester,
              items: [
                'Sem 1',
                'Sem 2',
                'Sem 3',
                'Sem 4',
                'Sem 5',
                'Sem 6',
              ]
                  .map((sem) => DropdownMenuItem(
                        value: sem,
                        child: Text(sem),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSemester = value!;
                });
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calculateAttendance,
              child: Text('Calculate Attendance'),
            ),
            SizedBox(height: 20),
            _attendanceData.isNotEmpty
                ? Expanded(
                    child: ListView.builder(
                      itemCount: _attendanceData.length,
                      itemBuilder: (context, index) {
                        final data = _attendanceData[index];
                        return ListTile(
                          title: Text('${data['name']} (${data['id']})'),
                          subtitle: Text(
                              'Attendance: ${data['attendancePercentage']}%'),
                        );
                      },
                    ),
                  )
                : Text('No attendance data available.'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _attendanceData.isNotEmpty ? _generatePDF : null,
              child: Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
