import 'package:flutter/material.dart';
import '../../data/models/room_config_model.dart';
import '../../data/database/room_repository.dart';
import '../../data/database/student_repository.dart';

class RoomProvider with ChangeNotifier {
  final RoomRepository _roomRepo = RoomRepository();
  final StudentRepository _studentRepo = StudentRepository();
  
  List<RoomConfigModel> _rooms = [];
  final Map<String, int> _occupancyMap = {};
  bool _isLoading = false;
  String _filter = 'all'; // 'all' or 'available'
  String _query = '';

  String get query => _query;

  void setQuery(String value) {
    final next = value.trim();
    if (_query == next) return;
    _query = next;
    notifyListeners();
  }

  List<RoomConfigModel> get rooms {
    return _rooms.where((room) {
      if (_filter == 'available') {
        final occupancy = _occupancyMap[room.roomNumber] ?? 0;
        if (occupancy >= room.capacity) return false;
      }
      if (_query.isEmpty) return true;
      return room.roomNumber.toLowerCase().contains(_query.toLowerCase());
    }).toList();
  }
  
  List<RoomConfigModel> get allRooms => _rooms;
  Map<String, int> get occupancyMap => _occupancyMap;
  bool get isLoading => _isLoading;
  String get currentFilter => _filter;

  // Load all rooms and calculate occupancy
  Future<void> loadRooms() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _rooms = await _roomRepo.getAllRooms();
      
      // Calculate occupancy for each room
      _occupancyMap.clear();
      for (var room in _rooms) {
        final occupancy = await _studentRepo.getRoomOccupancy(room.roomNumber);
        _occupancyMap[room.roomNumber] = occupancy;
      }
    } catch (e) {
      print('Error loading rooms: $e');
      _rooms = [];
      _occupancyMap.clear();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Set filter
  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  // Add a new room
  Future<bool> addRoom({
    required String roomNumber,
    required int capacity,
    required int price,
  }) async {
    try {
      // Prevent duplicate room numbers
      final existing = await _roomRepo.getRoomByNumber(roomNumber);
      if (existing != null) {
        print('Room $roomNumber already exists');
        return false;
      }

      final room = RoomConfigModel(
        roomNumber: roomNumber,
        capacity: capacity,
        price: price,
      );
      await _roomRepo.insertRoom(room);
      await loadRooms();
      return true;
    } catch (e) {
      print('Error adding room: $e');
      return false;
    }
  }

  // Delete room (only if no students assigned)
  Future<bool> deleteRoom(String roomNumber) async {
    try {
      final occupancy = await _studentRepo.getRoomOccupancy(roomNumber);
      if (occupancy > 0) {
        print('Cannot delete room $roomNumber, occupancy = $occupancy');
        return false;
      }

      await _roomRepo.deleteRoom(roomNumber);
      await loadRooms();
      return true;
    } catch (e) {
      print('Error deleting room: $e');
      return false;
    }
  }

  /// Save an edited room. Returns null on success, or a message explaining why
  /// the edit was rejected (e.g. the new bed count is below current occupancy).
  Future<String?> updateRoomDetails({
    required String roomNumber,
    required int capacity,
    required int price,
    required int ebBill,
  }) async {
    try {
      if (capacity < 1) return 'A room needs at least 1 bed.';
      if (price < 0) return 'Rent cannot be negative.';
      if (ebBill < 0) return 'EB bill cannot be negative.';

      final existing = await _roomRepo.getRoomByNumber(roomNumber);
      if (existing == null) return 'Room $roomNumber no longer exists.';

      final occupancy = await _studentRepo.getRoomOccupancy(roomNumber);
      if (capacity < occupancy) {
        return 'Room $roomNumber already has $occupancy students. '
            'Move someone out before shrinking it to $capacity beds.';
      }

      await _roomRepo.updateRoom(existing.copyWith(
        capacity: capacity,
        price: price,
        ebBill: ebBill,
      ));
      await loadRooms();
      return null;
    } catch (e) {
      print('Error updating room $roomNumber: $e');
      return 'Could not update room $roomNumber.';
    }
  }

  // Update room price
  Future<void> updateRoomPrice(String roomNumber, int newPrice) async {
    await _roomRepo.updateRoomPrice(roomNumber, newPrice);
    await loadRooms();
  }

  // Update price for all rooms with specific capacity
  Future<void> updatePriceByCapacity(int capacity, int newPrice) async {
    await _roomRepo.updatePriceByCapacity(capacity, newPrice);
    await loadRooms();
  }

  // Update room EB bill
  Future<void> updateEbBill(String roomNumber, int newEbBill) async {
    await _roomRepo.updateEbBill(roomNumber, newEbBill);
    await loadRooms();
  }

  // Reset all EB bills
  Future<void> resetAllEbBills() async {
    await _roomRepo.resetAllEbBills();
    await loadRooms();
  }

  // Get room by number
  RoomConfigModel? getRoomByNumber(String roomNumber) {
    try {
      return _rooms.firstWhere((room) => room.roomNumber == roomNumber);
    } catch (e) {
      return null;
    }
  }

  // Get total capacity
  int getTotalCapacity() {
    return _rooms.fold(0, (sum, room) => sum + room.capacity);
  }

  // Get total occupied
  int getTotalOccupied() {
    return _occupancyMap.values.fold(0, (sum, occupancy) => sum + occupancy);
  }

  // Get total available
  int getTotalAvailable() {
    return getTotalCapacity() - getTotalOccupied();
  }
}
