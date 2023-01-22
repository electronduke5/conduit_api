import 'package:conduit/conduit.dart';
import 'package:conduit_project/utils/app_response.dart';

import '../models/history.dart';

class AppHistoryController extends ResourceController {
  final ManagedContext managedContext;

  AppHistoryController(this.managedContext);

  static String createDescription(String table, int id) =>
      'Добавление в таблицу $table записи под id = $id';

  static String updateDescription(String table, int id) =>
      'Изменение записи под id = $id в таблице $table';

  static String deleteDescription(String table, int id) =>
      'Удаление записи под id = $id в таблице $table';

  void createRecord({required History model}) async {
    final qCreateRecord = Query<History>(managedContext)
      ..values.tableName = model.tableName
      ..values.description = model.description
      ..values.user?.id = model.user!.id
      ..values.dateCreated = DateTime.now();

    await qCreateRecord.insert();
  }

  @Operation.get()
  Future<Response> getRecords() async {
    try {
      final qRecords = Query<History>(managedContext)
        ..join(object: (x) => x.user);
      final records = await qRecords.fetch();
      for(var item in records){
        item.user!.removePropertiesFromBackingMap(['accessToken', 'refreshToken']);
      }
      return Response.ok(records);
    } catch (e) {
      return AppResponse.ok(message: e.toString());
    }
  }
}
