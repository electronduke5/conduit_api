import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/transaction.dart';
import 'package:conduit_project/models/user.dart';

class Asset extends ManagedObject<_Asset> implements _Asset {}
class _Asset{
  @primaryKey
  int? id;
  @Column(indexed: true)
  String? name;

  @Column(indexed: true, defaultValue: '0.0')
  double? balance;

  @Column(indexed: true, defaultValue: '0')
  int? type;
  @Relate(#assets, isRequired: true, onDelete: DeleteRule.cascade)
  User? user;

  ManagedSet<Transaction>? transactions;
}