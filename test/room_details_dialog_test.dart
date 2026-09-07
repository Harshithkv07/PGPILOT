// The edit panel that opens when a room card is tapped. Saving is covered by
// room_capacity_test.dart (it needs a real database, which testWidgets' fake
// async cannot drive), so this pins down the panel itself: what it shows, and
// how the bed stepper behaves before anything is written.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pg_management/data/models/room_config_model.dart';
import 'package:pg_management/data/models/student_model.dart';
import 'package:pg_management/logic/providers/room_provider.dart';
import 'package:pg_management/presentation/widgets/room_details_dialog.dart';

const _editTooltip = 'Edit room size, rent and EB bill';

Future<void> _pump(
  WidgetTester tester, {
  required RoomConfigModel room,
  List<StudentModel> students = const [],
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<RoomProvider>(
      create: (_) => RoomProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: RoomDetailsDialog(
            room: room,
            students: students,
            occupancy: students.length,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

void main() {
  final room = RoomConfigModel(
      roomNumber: '101', capacity: 3, price: 5000, ebBill: 400);

  testWidgets('the room summary reads as size, rent and EB bill',
      (tester) async {
    await _pump(tester, room: room);
    expect(find.text('3-Sharing • ₹5000/month • ₹400 EB'), findsOneWidget);
  });

  testWidgets('a room with no EB bill leaves it out of the summary',
      (tester) async {
    await _pump(
      tester,
      room: RoomConfigModel(
          roomNumber: '102', capacity: 2, price: 4000, ebBill: 0),
    );
    expect(find.text('2-Sharing • ₹4000/month'), findsOneWidget);
  });

  testWidgets('the panel opens pre-filled with the room\'s current numbers',
      (tester) async {
    await _pump(tester, room: room);

    // Stats are what show before editing starts.
    expect(find.text('Capacity'), findsOneWidget);
    expect(find.byTooltip('Add a bed'), findsNothing);

    await tester.tap(find.byTooltip(_editTooltip));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'Beds (sharing)'), '3');
    expect(_fieldText(tester, 'Rent / month'), '5000');
    expect(_fieldText(tester, 'EB bill'), '400');
  });

  testWidgets('the stepper adds and removes beds', (tester) async {
    await _pump(tester, room: room);
    await tester.tap(find.byTooltip(_editTooltip));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add a bed'));
    await tester.pump();
    expect(_fieldText(tester, 'Beds (sharing)'), '4');

    await tester.tap(find.byTooltip('Remove a bed'));
    await tester.pump();
    await tester.tap(find.byTooltip('Remove a bed'));
    await tester.pump();
    expect(_fieldText(tester, 'Beds (sharing)'), '2');
  });

  testWidgets('the stepper will not go below one bed', (tester) async {
    await _pump(
      tester,
      room: RoomConfigModel(
          roomNumber: '103', capacity: 1, price: 8000, ebBill: 0),
    );
    await tester.tap(find.byTooltip(_editTooltip));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove a bed'));
    await tester.pump();
    expect(_fieldText(tester, 'Beds (sharing)'), '1');
  });

  testWidgets('the panel says how many students are already in the room',
      (tester) async {
    await _pump(tester, room: room, students: [
      StudentModel(roomNumber: '101', name: 'Asha'),
      StudentModel(roomNumber: '101', name: 'Bhavna'),
    ]);
    await tester.tap(find.byTooltip(_editTooltip));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('2 students living here'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the panel puts the stats back', (tester) async {
    await _pump(tester, room: room);
    await tester.tap(find.byTooltip(_editTooltip));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add a bed'), findsNothing);
    expect(find.text('Capacity'), findsOneWidget);
  });
}
