import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/transaction.dart';
import 'package:conduit_project/models/user.dart';

class Category extends ManagedObject<_Category> implements _Category{}

class _Category{
  @primaryKey
  int? id;

  @Column(unique: true, indexed: true)
  String? name;

  @Relate(#categories, isRequired: true, onDelete: DeleteRule.cascade)
  User? user;

  @Column(defaultValue: 'false', omitByDefault: true)
  bool? isDeleted;
  ManagedSet<Transaction>? transactions;
}