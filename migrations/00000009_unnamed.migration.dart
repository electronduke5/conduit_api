import 'dart:async';
import 'package:conduit_core/conduit_core.dart';   

class Migration9 extends Migration { 
  @override
  Future upgrade() async {
   		database.deleteColumn("_Transaction", "target");
  }
  
  @override
  Future downgrade() async {}
  
  @override
  Future seed() async {}
}
    