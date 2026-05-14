class UserModel {
  String id;
  String name;
  String email;
  bool onlineStatus;
  
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.onlineStatus = false,
  });
  
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      onlineStatus: data['onlineStatus'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'onlineStatus': onlineStatus,
    };
  }
}