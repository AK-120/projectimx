import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayPage extends StatefulWidget {
  @override
  _HolidayPageState createState() => _HolidayPageState();
}

class _HolidayPageState extends State<HolidayPage> {
  DateTime _selectedHoliday = DateTime.now();
  DateTime? _startHoliday;
  DateTime? _endHoliday;
  TextEditingController _holidayNameController = TextEditingController();
  String _holidayType = 'Single Day';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year; // Set this to a valid year initially

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Holidays'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _holidayType,
              items: [
                DropdownMenuItem(
                    value: 'Single Day', child: Text('Single Day')),
                DropdownMenuItem(
                    value: 'Multiple Days', child: Text('Multiple Days')),
                DropdownMenuItem(
                    value: 'Weekend for Month',
                    child: Text('Weekend for Month')),
              ],
              onChanged: (value) {
                setState(() {
                  _holidayType = value!;
                  _startHoliday = null;
                  _endHoliday = null;
                });
              },
            ),
            SizedBox(height: 16),
            if (_holidayType == 'Single Day') ...[
              GestureDetector(
                onTap: _pickHolidayDate,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Holiday Date: ${_selectedHoliday.toLocal()}"
                          .split(' ')[0],
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ] else if (_holidayType == 'Multiple Days') ...[
              GestureDetector(
                onTap: () => _pickRangeDate('start'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Start Date: ${_startHoliday?.toLocal() ?? 'Not Selected'}"
                          .split(' ')[0],
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
              SizedBox(height: 16),
              GestureDetector(
                onTap: () => _pickRangeDate('end'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "End Date: ${_endHoliday?.toLocal() ?? 'Not Selected'}"
                          .split(' ')[0],
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ] else if (_holidayType == 'Weekend for Month') ...[
              DropdownButton<int>(
                value: _selectedMonth,
                items: List.generate(12, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text(
                        '${DateTime(0, index + 1).month} - ${DateTime(0, index + 1).toLocal().month}'),
                  );
                }),
                onChanged: (value) {
                  setState(() {
                    _selectedMonth = value!;
                  });
                },
              ),
              DropdownButton<int>(
                value: _selectedYear,
                items: List.generate(
                      20, // Allow the last 20 years for selection
                      (index) {
                        int yearOption = DateTime.now().year - 1 + index;
                        return DropdownMenuItem<int>(
                          value: yearOption,
                          child: Text('$yearOption'),
                        );
                      },
                    ).where((item) => item.value != _selectedYear).toList() +
                    [
                      DropdownMenuItem<int>(
                        value: _selectedYear,
                        child: Text('$_selectedYear'),
                      ),
                    ], // Add the selected year manually to ensure it is always present
                onChanged: (value) {
                  setState(() {
                    _selectedYear = value!;
                  });
                },
              ),
            ],
            SizedBox(height: 16),
            if (_holidayType != 'Weekend for Month')
              TextField(
                controller: _holidayNameController,
                decoration: InputDecoration(labelText: 'Holiday Name'),
              ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveHoliday,
              child: Text('Save Holiday'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickHolidayDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedHoliday,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedHoliday = pickedDate;
      });
    }
  }

  Future<void> _pickRangeDate(String type) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: type == 'start'
          ? (_startHoliday ?? DateTime.now())
          : (_endHoliday ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        if (type == 'start') {
          _startHoliday = pickedDate;
        } else {
          _endHoliday = pickedDate;
        }
      });
    }
  }

  Future<void> _saveHoliday() async {
    try {
      if (_holidayType == 'Single Day') {
        await FirebaseFirestore.instance.collection('holidays').add({
          'date': _selectedHoliday.toIso8601String(),
          'name': _holidayNameController.text.trim(),
        });
      } else if (_holidayType == 'Multiple Days' &&
          _startHoliday != null &&
          _endHoliday != null) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (DateTime current = _startHoliday!;
            current.isBefore(_endHoliday!) ||
                current.isAtSameMomentAs(_endHoliday!);
            current = current.add(Duration(days: 1))) {
          DocumentReference docRef =
              FirebaseFirestore.instance.collection('holidays').doc();
          batch.set(docRef, {
            'date': current.toIso8601String(),
            'name': _holidayNameController.text.trim(),
          });
        }
        await batch.commit();
      } else if (_holidayType == 'Weekend for Month') {
        await _addWeekendHolidays(_selectedYear, _selectedMonth);
      }
      _clearInputs();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Holiday(s) saved successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving holidays: $e')));
    }
  }

  void _clearInputs() {
    _holidayNameController.clear();
    setState(() {
      _selectedHoliday = DateTime.now();
      _startHoliday = null;
      _endHoliday = null;
    });
  }

  Future<void> _addWeekendHolidays(int year, int month) async {
    DateTime startOfMonth = DateTime(year, month, 1);
    DateTime endOfMonth =
        DateTime(year, month + 1, 1).subtract(Duration(days: 1));

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (DateTime day = startOfMonth;
        day.isBefore(endOfMonth) || day.isAtSameMomentAs(endOfMonth);
        day = day.add(Duration(days: 1))) {
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        DocumentReference docRef =
            FirebaseFirestore.instance.collection('holidays').doc();
        batch.set(docRef, {
          'date': day.toIso8601String(),
          'name': 'Weekend',
        });
      }
    }
    await batch.commit();
  }
}
