import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/user.dart';

class History extends ManagedObject<_History> implements _History {}

class _History {

  @primaryKey
  int? id;
  @Column()
  String? tableName;
  @Column()
  String? description;
  @Column()
  DateTime? dateCreated;

  @Relate(#histories, isRequired: true, onDelete: DeleteRule.cascade)
  User? user;
}
