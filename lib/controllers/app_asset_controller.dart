import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/user.dart';
import 'package:conduit_project/utils/app_utils.dart';

import '../models/asset.dart';
import '../models/history.dart';
import '../utils/app_response.dart';
import 'app_history_controller.dart';

class AppAssetController extends ResourceController {
  AppAssetController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> getAsset(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query('id') int? id,
    @Bind.query('filter') int? filter,
    @Bind.query('q') String? query,
    @Bind.query('page') int page = 1,
    @Bind.query('limit') int limit = 10,
  }) async {
    try {
      if (id != null) {
        final qAssets = Query<Asset>(managedContext)
          ..where((asset) => asset.id).equalTo(id)
          ..join(object: (user) => user.user);
        final asset = await qAssets.fetchOne();
        asset!.user!
            .removePropertiesFromBackingMap(['refreshToken', 'accessToken']);
        return Response.ok(asset);
      } else {
        final idUser = AppUtils.getIdFromHeader(header);

        final qAssets = Query<Asset>(managedContext)
          ..where((a) => a.user?.id).equalTo(idUser)
          ..where((asset) => asset.name)
              .contains(query ?? '', caseSensitive: false)
          ..offset = (page - 1) * limit
          ..fetchLimit = limit;
        if (filter != null) {
          qAssets.where((asset) => asset.type).identifiedBy(filter);
        }
        //..join(object: (user) => user.user);
        final assets = await qAssets.fetch();
        // for (var el in assets) {
        //   el.user!
        //       .removePropertiesFromBackingMap(['refreshToken', 'accessToken']);
        // }
        return Response.ok(assets);
      }
    } on QueryException catch (e) {
      print('e.message: ${e}');
      print('e.toString(): ${e.toString()}');
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.delete()
  Future<Response> deleteAsset(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query('id') int? id,
  }) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(idUser);
      final qDeleteAssets = Query<Asset>(managedContext)
        ..where((asset) => asset.id).equalTo(id)
        ..where((asset) => asset.user!.id).equalTo(idUser);
      await qDeleteAssets.delete();
      AppHistoryController(managedContext).createRecord(
          model: History()
            ..user = user
            ..description =
                AppHistoryController.deleteDescription('Asset', id!)
            ..tableName = 'Asset');
      return AppResponse.ok(message: 'Удаление прошло успешно');
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.put()
  Future<Response> createAsset(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Asset asset,
  ) async {
    if (asset.name == null || asset.balance == null) {
      return AppResponse.badRequest(
          message: 'Поля название и баланс обязательны');
    }
    try {
      late final int id;
      final idUser = AppUtils.getIdFromHeader(header);

      final user = await managedContext.fetchObjectWithID<User>(idUser);
      await managedContext.transaction((transaction) async {
        final qCreateAsset = Query<Asset>(transaction)
          ..values.balance = asset.balance
          ..values.name = asset.name
          ..values.type = asset.type
          ..values.user = user;

        final createdAsset = await qCreateAsset.insert();
        id = createdAsset.id!;
      });
      final assetData = await managedContext.fetchObjectWithID<Asset>(id);
      AppHistoryController(managedContext).createRecord(
          model: History()
            ..user = user
            ..description = AppHistoryController.createDescription('Asset', assetData!.id!)
            ..tableName = 'Asset');
      return Response.ok(assetData);
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.post()
  Future<Response> updateAsset(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Asset asset,
    @Bind.query('id') int assetId,
  ) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(idUser);

      final qFindAsset = Query<Asset>(managedContext)
        ..where((asset) => asset.id).equalTo(assetId);
      final fAsset = await qFindAsset.fetchOne();
      //TODO:Null check operator used on a null value

      final qUpdateAsset = Query<Asset>(managedContext)
        ..where((asset) => asset.id).equalTo(assetId)
        ..values.name = asset.name ?? fAsset!.name
        ..values.balance = asset.balance ?? fAsset!.balance
        ..values.type = asset.type ?? fAsset!.type;

      await qUpdateAsset.updateOne();

      final newAsset = await qFindAsset.fetchOne();
      AppHistoryController(managedContext).createRecord(
          model: History()
            ..user = user
            ..description = AppHistoryController.updateDescription('Asset', newAsset!.id!)
            ..tableName = 'Asset');
      return Response.ok(newAsset);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }
}
