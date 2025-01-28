import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimeRestrictionPage extends StatefulWidget {
  @override
  _TimeRestrictionPageState createState() => _TimeRestrictionPageState();
}

class _TimeRestrictionPageState extends State<TimeRestrictionPage> {
  String? selectedDay;
  TimeOfDay? morningCheckInStart,
      morningCheckInEnd,
      morningCheckOutStart,
      morningCheckOutEnd;
  TimeOfDay? afternoonCheckInStart,
      afternoonCheckInEnd,
      afternoonCheckOutStart,
      afternoonCheckOutEnd;

  Map<String, dynamic>? timeRestrictions;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTimeRestrictions();
  }

  Future<void> _fetchTimeRestrictions() async {
    setState(() => isLoading = true);
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('time_restrictions')
          .get();

      Map<String, dynamic> fetchedData = {};
      for (var doc in docSnapshot.docs) {
        fetchedData[doc.id] = doc.data();
      }

      setState(() {
        timeRestrictions = fetchedData;
      });
    } catch (e) {
      print("Error fetching time restrictions: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching time restrictions")),
      );
    }
    setState(() => isLoading = false);
  }

  Future<TimeOfDay?> _selectTime(
      BuildContext context, TimeOfDay initialTime) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
  }

  void _saveTimeRestriction() async {
    if (selectedDay == null ||
        morningCheckInStart == null ||
        morningCheckInEnd == null ||
        morningCheckOutStart == null ||
        morningCheckOutEnd == null ||
        afternoonCheckInStart == null ||
        afternoonCheckInEnd == null ||
        afternoonCheckOutStart == null ||
        afternoonCheckOutEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in all time slots")),
      );
      return;
    }

    try {
      final timeData = {
        'morning_check_in_start': '${morningCheckInStart!.format(context)}',
        'morning_check_in_end': '${morningCheckInEnd!.format(context)}',
        'morning_check_out_start': '${morningCheckOutStart!.format(context)}',
        'morning_check_out_end': '${morningCheckOutEnd!.format(context)}',
        'afternoon_check_in_start': '${afternoonCheckInStart!.format(context)}',
        'afternoon_check_in_end': '${afternoonCheckInEnd!.format(context)}',
        'afternoon_check_out_start':
            '${afternoonCheckOutStart!.format(context)}',
        'afternoon_check_out_end': '${afternoonCheckOutEnd!.format(context)}',
      };

      await FirebaseFirestore.instance
          .collection('time_restrictions')
          .doc(selectedDay)
          .set(timeData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Time restrictions saved successfully")),
      );

      _fetchTimeRestrictions(); // Refresh data
    } catch (e) {
      print('Error saving time restrictions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data")),
      );
    }
  }

  void _deleteTimeRestriction(String day) async {
    try {
      await FirebaseFirestore.instance
          .collection('time_restrictions')
          .doc(day)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Time restriction deleted for $day")),
      );

      _fetchTimeRestrictions(); // Refresh data
    } catch (e) {
      print("Error deleting time restriction: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting time restriction")),
      );
    }
  }

  void _populateFieldsForEdit(String day) {
    final data = timeRestrictions![day];
    setState(() {
      selectedDay = day;
      morningCheckInStart = _parseTime(data['morning_check_in_start']);
      morningCheckInEnd = _parseTime(data['morning_check_in_end']);
      morningCheckOutStart = _parseTime(data['morning_check_out_start']);
      morningCheckOutEnd = _parseTime(data['morning_check_out_end']);
      afternoonCheckInStart = _parseTime(data['afternoon_check_in_start']);
      afternoonCheckInEnd = _parseTime(data['afternoon_check_in_end']);
      afternoonCheckOutStart = _parseTime(data['afternoon_check_out_start']);
      afternoonCheckOutEnd = _parseTime(data['afternoon_check_out_end']);
    });
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null || time.isEmpty) return null;

    // Check if the time includes AM/PM
    final regex = RegExp(r'(\d{1,2}):(\d{2})\s?(AM|PM)?');
    final match = regex.firstMatch(time);

    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final amPm = match.group(3);

      // Convert to 24-hour format
      int finalHour = hour;

      if (amPm != null) {
        if (amPm == 'PM' && hour < 12) {
          finalHour += 12;
        } else if (amPm == 'AM' && hour == 12) {
          finalHour = 0; // midnight case
        }
      }

      return TimeOfDay(hour: finalHour, minute: minute);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Time Restrictions'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dropdown for day selection
                  DropdownButton<String>(
                    value: selectedDay,
                    hint: Text("Select a day"),
                    onChanged: (value) {
                      setState(() {
                        selectedDay = value;
                      });
                    },
                    items:
                        ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
                            .map((day) => DropdownMenuItem<String>(
                                  value: day,
                                  child: Text(day),
                                ))
                            .toList(),
                  ),
                  SizedBox(height: 20),

                  // Time Picker Rows
                  _buildTimePickerRow(
                    "Morning Check-in:",
                    morningCheckInStart,
                    morningCheckInEnd,
                    (time) => morningCheckInStart = time,
                    (time) => morningCheckInEnd = time,
                  ),
                  SizedBox(height: 20),
                  _buildTimePickerRow(
                    "Morning Check-out:",
                    morningCheckOutStart,
                    morningCheckOutEnd,
                    (time) => morningCheckOutStart = time,
                    (time) => morningCheckOutEnd = time,
                  ),
                  SizedBox(height: 20),
                  _buildTimePickerRow(
                    "Afternoon Check-in:",
                    afternoonCheckInStart,
                    afternoonCheckInEnd,
                    (time) => afternoonCheckInStart = time,
                    (time) => afternoonCheckInEnd = time,
                  ),
                  SizedBox(height: 20),
                  _buildTimePickerRow(
                    "Afternoon Check-out:",
                    afternoonCheckOutStart,
                    afternoonCheckOutEnd,
                    (time) => afternoonCheckOutStart = time,
                    (time) => afternoonCheckOutEnd = time,
                  ),
                  SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    onPressed: _saveTimeRestriction,
                    child: Text('Save Time Restrictions'),
                  ),
                  SizedBox(height: 20),

                  // Show existing time restrictions
                  if (timeRestrictions != null)
                    Expanded(
                      child: ListView(
                        children: timeRestrictions!.keys.map((day) {
                          final data = timeRestrictions![day];
                          return ListTile(
                            title: Text(day),
                            subtitle: Text(
                              'Morning: ${data['morning_check_in_start']} - ${data['morning_check_out_end']}\n'
                              'Afternoon: ${data['afternoon_check_in_start']} - ${data['afternoon_check_out_end']}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () => _populateFieldsForEdit(day),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => _deleteTimeRestriction(day),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTimePickerRow(
    String label,
    TimeOfDay? start,
    TimeOfDay? end,
    Function(TimeOfDay?) onStartChanged,
    Function(TimeOfDay?) onEndChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Row(
          children: [
            ElevatedButton(
              onPressed: () async {
                final time = await _selectTime(context, TimeOfDay.now());
                if (time != null) onStartChanged(time);
                setState(() {});
              },
              child: Text(start != null ? start.format(context) : 'Start Time'),
            ),
            SizedBox(width: 20),
            ElevatedButton(
              onPressed: () async {
                final time = await _selectTime(context, TimeOfDay.now());
                if (time != null) onEndChanged(time);
                setState(() {});
              },
              child: Text(end != null ? end.format(context) : 'End Time'),
            ),
          ],
        ),
      ],
    );
  }
}
