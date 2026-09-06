class RoomConfigModel {
  final String roomNumber;
  final int capacity;
  final int price;
  final int ebBill;

  RoomConfigModel({
    required this.roomNumber,
    required this.capacity,
    required this.price,
    this.ebBill = 0,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'room_number': roomNumber,
      'capacity': capacity,
      'price': price,
      'eb_bill': ebBill,
    };
  }

  // Create from Map
  factory RoomConfigModel.fromMap(Map<String, dynamic> map) {
    return RoomConfigModel(
      roomNumber: map['room_number'],
      capacity: map['capacity'],
      price: map['price'],
      ebBill: map['eb_bill'] ?? 0,
    );
  }

  // Copy with method for updates
  RoomConfigModel copyWith({
    String? roomNumber,
    int? capacity,
    int? price,
    int? ebBill,
  }) {
    return RoomConfigModel(
      roomNumber: roomNumber ?? this.roomNumber,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      ebBill: ebBill ?? this.ebBill,
    );
  }
}
