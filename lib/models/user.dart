import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/asset.dart';
import 'package:conduit_project/models/category.dart';
import 'package:conduit_project/models/history.dart';

class User extends ManagedObject<_User> implements _User {}

class _User {
  @primaryKey
  int? id;

  @Column(unique: true, indexed: true)
  String? userName;

  @Column(unique: true, indexed: true)
  String? email;

  @Serialize(input: true, output: true)
  String? password;

  @Column(nullable: true)
  String? accessToken;

  @Column(nullable: true)
  String? refreshToken;

  @Column(omitByDefault: true)
  String? salt;

  @Column(omitByDefault: true)
  String? hashPassword;

  ManagedSet<Asset>? assets;
  ManagedSet<Category>? categories;
  ManagedSet<History>? histories;
}