import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

class AttendanceSearchPage extends StatefulWidget {
  @override
  _AttendanceSearchPageState createState() => _AttendanceSearchPageState();
}

class _AttendanceSearchPageState extends State<AttendanceSearchPage> {
  String selectedDept = "Computer Engineering";
  String selectedSemester = "Sem 6";
  String selectedStudent = ""; // Selected student name
  DateTime selectedMonth = DateTime.now();

  List<String> departments = [
    "Computer Engineering",
    "Electronics Engineering",
    "Printing Technology"
  ];
  List<String> semesters = [
    "Sem 1",
    "Sem 2",
    "Sem 3",
    "Sem 4",
    "Sem 5",
    "Sem 6"
  ];
  List<String> studentNames = [];
  List<Map<String, dynamic>> attendanceRecords = [];
  List<String> holidayList = ["2025-01-26"]; // Example holiday list

  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchAttendanceData();
    fetchStudents();
  }

  Future<void> fetchAttendanceData() async {
    setState(() => isLoading = true);
    try {
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('department', isEqualTo: selectedDept)
          .where('semester', isEqualTo: selectedSemester)
          .get();

      setState(() {
        attendanceRecords = attendanceQuery.docs.map((doc) {
          return doc.data() as Map<String, dynamic>;
        }).toList();
        errorMessage =
            attendanceRecords.isEmpty ? "No attendance data found." : "";
      });
    } catch (e) {
      setState(() => errorMessage = 'Error fetching attendance data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: selectedDept)
          .where('semester', isEqualTo: selectedSemester)
          .get();

      setState(() {
        studentNames = studentsQuery.docs
            .map((doc) => doc.data()['name'].toString())
            .toList();
        errorMessage = studentNames.isEmpty ? "No students found." : "";
        selectedStudent = ""; // Reset selection
      });
    } catch (e) {
      setState(() => errorMessage = 'Error fetching students: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<String> getAllWorkingDays() {
    DateTime firstDayOfMonth =
        DateTime(selectedMonth.year, selectedMonth.month, 1);
    DateTime lastDayOfMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

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

  String getLastWorkingDay() {
    DateTime today = DateTime.now();

    while (today.weekday == DateTime.saturday ||
        today.weekday == DateTime.sunday) {
      today = today.subtract(Duration(days: 1));
    }

    return DateFormat('yyyy-MM-dd').format(today);
  }

  List<String> getAbsentDays() {
    List<String> workingDays = getAllWorkingDays();
    String lastWorkingDay = getLastWorkingDay();

    List<String> filteredWorkingDays =
        workingDays.where((day) => day.compareTo(lastWorkingDay) <= 0).toList();

    List<String> presentDays = attendanceRecords
        .where((record) =>
            record['name'] == selectedStudent &&
            record['time_in'] != null &&
            record['date'] != null)
        .map((record) {
      DateTime parsedDate = DateFormat('yyyy-M-d').parse(record['date']);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    }).toList();

    print("Working Days: $filteredWorkingDays");
    print("Present Days: $presentDays");

    List<String> absentDays =
        filteredWorkingDays.where((day) => !presentDays.contains(day)).toList();

    print("Absent Days: $absentDays");

    return absentDays;
  }

  List<String> getPresentDays() {
    List<String> workingDays = getAllWorkingDays();

    List<String> presentDays = attendanceRecords
        .where((record) =>
            record['name'] == selectedStudent &&
            record['time_in'] != null &&
            record['date'] != null)
        .map((record) {
      DateTime parsedDate = DateFormat('yyyy-M-d').parse(record['date']);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    }).toList();

    print("Working Days: $workingDays");
    print("Present Days: $presentDays");

    return workingDays.where((day) => presentDays.contains(day)).toList();
  }

  Future<void> pickMonth(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(selectedMonth.year, selectedMonth.month,
          1), // Ensure it's the first day of the month
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      // Allow only the first day of each month to be selectable
      selectableDayPredicate: (day) =>
          day.day == 1 && day.isBefore(DateTime.now().add(Duration(days: 1))),
    );

    if (pickedDate != null) {
      setState(() {
        // Save only the month and year from the picked date
        selectedMonth = DateTime(pickedDate.year, pickedDate.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Search'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Selected Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}",
                        style: TextStyle(fontSize: 16),
                      ),
                      Spacer(),
                      ElevatedButton(
                        onPressed: () => pickMonth(context),
                        child: Text('Pick Month'),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedDept,
                          decoration: InputDecoration(labelText: "Department"),
                          onChanged: (value) {
                            setState(() {
                              selectedDept = value!;
                              fetchStudents();
                            });
                          },
                          items: departments
                              .map((dept) => DropdownMenuItem(
                                    value: dept,
                                    child: Text(dept),
                                  ))
                              .toList(),
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedSemester,
                          decoration: InputDecoration(labelText: "Semester"),
                          onChanged: (value) {
                            setState(() {
                              selectedSemester = value!;
                              fetchStudents();
                            });
                          },
                          items: semesters
                              .map((sem) => DropdownMenuItem(
                                    value: sem,
                                    child: Text(sem),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedStudent.isEmpty ? null : selectedStudent,
                    decoration: InputDecoration(labelText: "Student"),
                    onChanged: (value) {
                      setState(() {
                        selectedStudent = value!;
                      });
                    },
                    items: studentNames
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ))
                        .toList(),
                  ),
                  SizedBox(height: 20),
                  if (selectedStudent.isNotEmpty) ...[
                    Text(
                      "Attendance Summary:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text("Total Working Days: ${getAllWorkingDays().length}"),
                    Text("Total Absent Days: ${getAbsentDays().length}"),
                    SizedBox(height: 10),
                    Flexible(
                      child: ListView(
                        children: [
                          Text(
                            "Present Days:",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ...getPresentDays().map((date) => ListTile(
                                title: Text(date),
                                leading: Icon(Icons.check, color: Colors.green),
                              )),
                          SizedBox(height: 10),
                          Text(
                            "Absent Days:",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ...getAbsentDays().map(
                            (date) => ListTile(
                              title: Text(date),
                              leading: Icon(Icons.cancel, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (errorMessage.isNotEmpty)
                    Center(child: Text(errorMessage)),
                ],
              ),
            ),
    );
  }
}
