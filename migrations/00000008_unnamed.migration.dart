import 'dart:async';
import 'package:conduit_core/conduit_core.dart';   

class Migration8 extends Migration { 
  @override
  Future upgrade() async {
   		database.addColumn("_Asset", SchemaColumn.relationship("user", ManagedPropertyType.bigInteger, relatedTableName: "_User", relatedColumnName: "id", rule: DeleteRule.cascade, isNullable: false, isUnique: false));
  }
  
  @override
  Future downgrade() async {}
  
  @override
  Future seed() async {}
}
    