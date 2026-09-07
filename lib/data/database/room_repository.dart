import '../models/room_config_model.dart';
import 'database_helper.dart';

class RoomRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Get all rooms, lowest room code first.
  //
  // room_number used to be an INTEGER PRIMARY KEY (i.e. the rowid), so rows
  // came back in room order for free. As TEXT it needs an explicit sort, or
  // rooms would appear in whatever order they were created.
  Future<List<RoomConfigModel>> getAllRooms() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query('rooms', orderBy: 'room_number');
    return List.generate(maps.length, (i) => RoomConfigModel.fromMap(maps[i]));
  }

  // Get room by number
  Future<RoomConfigModel?> getRoomByNumber(String roomNumber) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rooms',
      where: 'room_number = ?',
      whereArgs: [roomNumber],
    );
    
    if (maps.isEmpty) return null;
    return RoomConfigModel.fromMap(maps.first);
  }

  // Get rooms by capacity
  Future<List<RoomConfigModel>> getRoomsByCapacity(int capacity) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'rooms',
      where: 'capacity = ?',
      whereArgs: [capacity],
    );
    return List.generate(maps.length, (i) => RoomConfigModel.fromMap(maps[i]));
  }

  // Update room price
  Future<int> updateRoomPrice(String roomNumber, int newPrice) async {
    final db = await _dbHelper.database;
    return await db.update(
      'rooms',
      {'price': newPrice},
      where: 'room_number = ?',
      whereArgs: [roomNumber],
    );
  }

  // Update price for all rooms with specific capacity
  Future<int> updatePriceByCapacity(int capacity, int newPrice) async {
    final db = await _dbHelper.database;
    return await db.update(
      'rooms',
      {'price': newPrice},
      where: 'capacity = ?',
      whereArgs: [capacity],
    );
  }

  // Update a room's bed count. Callers must check occupancy first: shrinking a
  // room below the number of students living in it would strand them.
  Future<int> updateRoomCapacity(String roomNumber, int newCapacity) async {
    final db = await _dbHelper.database;
    return await db.update(
      'rooms',
      {'capacity': newCapacity},
      where: 'room_number = ?',
      whereArgs: [roomNumber],
    );
  }

  // Update capacity, price and EB bill in one write.
  Future<int> updateRoom(RoomConfigModel room) async {
    final db = await _dbHelper.database;
    return await db.update(
      'rooms',
      {
        'capacity': room.capacity,
        'price': room.price,
        'eb_bill': room.ebBill,
      },
      where: 'room_number = ?',
      whereArgs: [room.roomNumber],
    );
  }

  // Update room EB Bill
  Future<int> updateEbBill(String roomNumber, int newEbBill) async {
    final db = await _dbHelper.database;
    return await db.update(
      'rooms',
      {'eb_bill': newEbBill},
      where: 'room_number = ?',
      whereArgs: [roomNumber],
    );
  }

  // Reset all EB Bills to 0
  Future<int> resetAllEbBills() async {
    final db = await _dbHelper.database;
    return await db.update(
      'rooms',
      {'eb_bill': 0},
    );
  }

  // Insert a new room
  Future<int> insertRoom(RoomConfigModel room) async {
    final db = await _dbHelper.database;
    return await db.insert('rooms', room.toMap());
  }

  // Delete room
  Future<int> deleteRoom(String roomNumber) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'rooms',
      where: 'room_number = ?',
      whereArgs: [roomNumber],
    );
  }
}
