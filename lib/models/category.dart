import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/transaction.dart';

class Category extends ManagedObject<_Category> implements _Category{}

class _Category{
  @primaryKey
  int? id;

  @Column(unique: true, indexed: true)
  String? name;


  ManagedSet<Transaction>? transactions;
}