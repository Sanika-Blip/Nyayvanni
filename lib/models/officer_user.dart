class OfficerUser {
  final String id;
  final String officerId;
  final String fullName;
  final String email;
  final String phone;
  final String rank;
  final String badgeNumber;
  final String station;
  final String district;
  final String state;
  final String address;
  final String status;

  const OfficerUser({
    required this.id,
    required this.officerId,
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.rank = '',
    this.badgeNumber = '',
    this.station = '',
    this.district = '',
    this.state = '',
    this.address = '',
    this.status = 'active',
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PO';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory OfficerUser.fromJson(Map<String, dynamic> json) {
    return OfficerUser(
      id: json['id'] as String? ?? '',
      officerId: json['officerId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      rank: json['rank'] as String? ?? '',
      badgeNumber: json['badgeNumber'] as String? ?? '',
      station: json['station'] as String? ?? '',
      district: json['district'] as String? ?? '',
      state: json['state'] as String? ?? '',
      address: json['address'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'officerId': officerId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'rank': rank,
        'badgeNumber': badgeNumber,
        'station': station,
        'district': district,
        'state': state,
        'address': address,
        'status': status,
      };
}
