import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final TextEditingController _monthController =
      TextEditingController(); // Input: Year-Month
  final TextEditingController _workingDaysController =
      TextEditingController(); // Input: Working days
  String _selectedDepartment = "Computer Engineering";
  String _selectedSemester = "S6";
  List<Map<String, dynamic>> _attendanceData = [];

  Future<void> _fetchAttendanceData(int workingDays, String monthYear) async {
    List<Map<String, dynamic>> attendanceData = [];
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: _selectedDepartment)
          .where('semester', isEqualTo: _selectedSemester)
          .get();

      for (var userDoc in userSnapshot.docs) {
        final userId = userDoc['id'];
        final userName = userDoc['name'];

        // Fetch attendance for the given month and year
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('id', isEqualTo: userId)
            .where('date', isGreaterThanOrEqualTo: "$monthYear-01")
            .where('date', isLessThanOrEqualTo: "$monthYear-31")
            .get();

        int daysPresent = attendanceSnapshot.docs.length;
        int totalAttendance = await FirebaseFirestore.instance
            .collection('attendance')
            .where('id', isEqualTo: userId)
            .get()
            .then((snapshot) => snapshot.docs.length);

        double percentage = (daysPresent / workingDays) * 100;

        attendanceData.add({
          'id': userId,
          'name': userName,
          'monthAttendance': daysPresent,
          'totalAttendance': totalAttendance,
          'monthPercentage': percentage.toStringAsFixed(2),
        });
      }

      setState(() {
        _attendanceData = attendanceData;
      });
    } catch (e) {
      print('Error fetching attendance data: $e');
    }
  }

  Future<void> _downloadPDF() async {
    final pdf = pw.Document();

    // Parse the month and year from input
    final monthYearInput = _monthController.text; // e.g., "2024-12"
    final parts = monthYearInput.split('-');
    final year = parts[0];
    final month = parts[1];

    // Map month numbers to names
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthName = monthNames[int.parse(month) - 1];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ATTENDANCE STATEMENT FOR THE MONTH OF $monthName $year',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Programme: $_selectedDepartment'),
              pw.Text('Semester: $_selectedSemester'),
              pw.Text(
                  'No. of working days in $monthName $year: ${_workingDaysController.text}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  'Adm. No.',
                  'Name',
                  '$monthName $year',
                  'Total Attended',
                  'Attendance %'
                ],
                data: _attendanceData.map((data) {
                  return [
                    data['id'],
                    data['name'],
                    data['monthAttendance'],
                    data['totalAttendance'],
                    '${data['monthPercentage']}%',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    try {
      String? outputDir = await FilePicker.platform.getDirectoryPath();
      if (outputDir == null) return;

      final path =
          '$outputDir/attendance_report_${monthName.toLowerCase()}_$year.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved to $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate Attendance Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _monthController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Enter Month and Year (YYYY-MM)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _workingDaysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter Working Days',
                border: OutlineInputBorder(),
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final workingDays =
                    int.tryParse(_workingDaysController.text) ?? 30;
                final monthYear = _monthController.text;
                await _fetchAttendanceData(workingDays, monthYear);
              },
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
                          subtitle:
                              Text('Attendance: ${data['monthPercentage']}%'),
                        );
                      },
                    ),
                  )
                : Text('No attendance data available.'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _attendanceData.isNotEmpty ? _downloadPDF : null,
              child: Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
