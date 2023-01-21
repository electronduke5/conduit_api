import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/response.dart';
import 'package:conduit_project/models/user.dart';
import 'package:conduit_project/utils/app_utils.dart';

import '../models/asset.dart';
import '../utils/app_response.dart';

class AppAssetController extends ResourceController {
  AppAssetController(this.managedContext);

  final ManagedContext managedContext;

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
      //TODO: Убрать substring (в Postman в начале токена написано Bearer *токен*)
      header = header.substring(7);
      final idUser = AppUtils.getIdFromToken(header);

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
      print(assetData!.name);
      print(assetData.backing.contents);
      return Response.ok(ModelResponse(
          data: assetData.backing.contents,
          message: 'Успешное создание счета'));
      // return AppResponse.ok(
      //     body: assetData!.backing.contents,
      //     message: 'Успешное создание счета');
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }
}
