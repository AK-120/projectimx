import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadTimetableScreen extends StatefulWidget {
  @override
  _UploadTimetableScreenState createState() => _UploadTimetableScreenState();
}

class _UploadTimetableScreenState extends State<UploadTimetableScreen> {
  String? selectedBranch;
  String? selectedSemester;
  String? selectedDay;
  List<Map<String, String>> periods = [];

  final branchOptions = [
    "Computer Engineering",
    "Electronics Engineering",
    "Printing Technology"
  ];
  final semesterOptions = [
    'Sem 1',
    'Sem 2',
    'Sem 3',
    'Sem 4',
    'Sem 5',
    'Sem 6',
  ];
  final dayOptions = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
  ];

  final subjectController = TextEditingController();
  String? selectedTimeRange; // Stores the selected time range

  // Method to pick a time range
  Future<void> pickTimeRange(BuildContext context) async {
    TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (startTime != null) {
      TimeOfDay? endTime = await showTimePicker(
        context: context,
        initialTime: startTime,
      );

      if (endTime != null) {
        setState(() {
          selectedTimeRange =
              "${startTime.format(context)} - ${endTime.format(context)}";
        });
      }
    }
  }

  void addPeriod() {
    if (selectedTimeRange != null && subjectController.text.isNotEmpty) {
      setState(() {
        periods.add({
          "time": selectedTimeRange!,
          "subject": subjectController.text,
        });
        selectedTimeRange = null;
        subjectController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select time and enter subject.")),
      );
    }
  }

  Future<void> uploadTimetable() async {
    if (selectedBranch != null &&
        selectedSemester != null &&
        selectedDay != null &&
        periods.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('timetable').add({
          "branch": selectedBranch,
          "semester": selectedSemester,
          "day": selectedDay,
          "periods": periods,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Timetable uploaded successfully!")),
        );

        setState(() {
          periods.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading timetable: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields and add periods.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Upload Timetable")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Branch Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Select Branch"),
                value: selectedBranch,
                items: branchOptions
                    .map((branch) => DropdownMenuItem(
                          value: branch,
                          child: Text(branch),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedBranch = value),
              ),
              SizedBox(height: 16),

              // Semester Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Select Semester"),
                value: selectedSemester,
                items: semesterOptions
                    .map((semester) => DropdownMenuItem<String>(
                          value: semester,
                          child: Text(semester),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSemester = value;
                  });
                },
              ),
              SizedBox(height: 16),

              // Day Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: "Select Day"),
                value: selectedDay,
                items: dayOptions
                    .map((day) => DropdownMenuItem(
                          value: day,
                          child: Text(day),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => selectedDay = value),
              ),
              SizedBox(height: 16),

              // Time and Subject Input
              GestureDetector(
                onTap: () => pickTimeRange(context),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    selectedTimeRange ?? "Select Time Range",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(labelText: "Subject"),
              ),
              SizedBox(height: 16),

              ElevatedButton(
                onPressed: addPeriod,
                child: Text("Add Period"),
              ),
              SizedBox(height: 16),

              // Display Added Periods
              if (periods.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Added Periods:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...periods.map((period) =>
                        Text("${period['time']} - ${period['subject']}")),
                  ],
                ),
              SizedBox(height: 16),

              // Upload Button
              ElevatedButton(
                onPressed: uploadTimetable,
                child: Text("Upload Timetable"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
