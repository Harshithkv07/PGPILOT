class StudentModel {
  final int? id;
  final String roomNumber;
  final String name;
  final String dob;
  final String contact;
  final String fatherName;
  final String fatherNumber;
  final String motherName;
  final String motherNumber;
  final String college;
  final String hometown;
  final String address;
  final String advanceAmount;
  final String rentStatus;
  final String paymentMode;

  /// The advance as a number. The underlying column is TEXT for historical
  /// reasons and may hold anything previously typed, so this parses leniently
  /// and falls back to 0 rather than throwing.
  double get advanceAmountValue =>
      double.tryParse(advanceAmount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  /// Rent settled so far for the *current* month, across every instalment.
  /// Archived months keep their own totals in `payment_history`.
  final double amountPaid;
  final String? aadharCard;
  final String? aadharName;
  final String? studentPicture;
  final String? studentPictureName;

  /// Only [roomNumber] and [name] are required. Every other detail can be
  /// filled in later, so they default to an empty string — the underlying
  /// columns are NOT NULL, so '' is used rather than null.
  StudentModel({
    this.id,
    required this.roomNumber,
    required this.name,
    this.dob = '',
    this.contact = '',
    this.fatherName = '',
    this.fatherNumber = '',
    this.motherName = '',
    this.motherNumber = '',
    this.college = '',
    this.hometown = '',
    this.address = '',
    this.advanceAmount = '',
    this.rentStatus = 'Pending',
    this.paymentMode = '-',
    this.amountPaid = 0,
    this.aadharCard,
    this.aadharName,
    this.studentPicture,
    this.studentPictureName,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'room_number': roomNumber,
      'name': name,
      'dob': dob,
      'contact': contact,
      'father_name': fatherName,
      'father_number': fatherNumber,
      'mother_name': motherName,
      'mother_number': motherNumber,
      'college': college,
      'hometown': hometown,
      'address': address,
      'advance_amount': advanceAmount,
      'rent_status': rentStatus,
      'payment_mode': paymentMode,
      'amount_paid': amountPaid,
      'aadhar_card': aadharCard,
      'aadhar_name': aadharName,
      'student_picture': studentPicture,
      'student_picture_name': studentPictureName,
    };
  }

  // Create from Map
  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'],
      roomNumber: map['room_number'],
      name: map['name'],
      dob: map['dob'] ?? '',
      contact: map['contact'] ?? '',
      fatherName: map['father_name'] ?? '',
      fatherNumber: map['father_number'] ?? '',
      motherName: map['mother_name'] ?? '',
      motherNumber: map['mother_number'] ?? '',
      college: map['college'] ?? '',
      hometown: map['hometown'] ?? '',
      address: map['address'] ?? '',
      advanceAmount: map['advance_amount'] ?? '',
      rentStatus: map['rent_status'] ?? 'Pending',
      paymentMode: map['payment_mode'] ?? '-',
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      aadharCard: map['aadhar_card'],
      aadharName: map['aadhar_name'],
      studentPicture: map['student_picture'],
      studentPictureName: map['student_picture_name'],
    );
  }

  // Copy with method for updates
  StudentModel copyWith({
    int? id,
    String? roomNumber,
    String? name,
    String? dob,
    String? contact,
    String? fatherName,
    String? fatherNumber,
    String? motherName,
    String? motherNumber,
    String? college,
    String? hometown,
    String? address,
    String? advanceAmount,
    String? rentStatus,
    String? paymentMode,
    double? amountPaid,
    String? aadharCard,
    String? aadharName,
    String? studentPicture,
    String? studentPictureName,
  }) {
    return StudentModel(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      name: name ?? this.name,
      dob: dob ?? this.dob,
      contact: contact ?? this.contact,
      fatherName: fatherName ?? this.fatherName,
      fatherNumber: fatherNumber ?? this.fatherNumber,
      motherName: motherName ?? this.motherName,
      motherNumber: motherNumber ?? this.motherNumber,
      college: college ?? this.college,
      hometown: hometown ?? this.hometown,
      address: address ?? this.address,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      rentStatus: rentStatus ?? this.rentStatus,
      paymentMode: paymentMode ?? this.paymentMode,
      amountPaid: amountPaid ?? this.amountPaid,
      aadharCard: aadharCard ?? this.aadharCard,
      aadharName: aadharName ?? this.aadharName,
      studentPicture: studentPicture ?? this.studentPicture,
      studentPictureName: studentPictureName ?? this.studentPictureName,
    );
  }
}
