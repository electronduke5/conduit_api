import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/transaction.dart';
import 'package:conduit_project/utils/app_response.dart';

import '../models/asset.dart';
import '../models/response.dart';
import '../utils/app_utils.dart';

class AppTransactionController extends ResourceController {
  final ManagedContext context;

  AppTransactionController(this.context);

  @Operation.get()
  Future<Response> get(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query("id") int? id,
    @Bind.query("q") String? query,
    @Bind.query("page") int page = 1,
    @Bind.query("limit") int limit = 10,
    @Bind.query("category") int? categoryId,
    @Bind.query("asset") int? assetId,
  }) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      if (id != null) {
        final qFind = Query<Transaction>(context)
          ..where((x) => x.id).equalTo(id)
          ..join(object: (x) => x.category)
          ..join(object: (x) => x.asset).join(object: (x) => x.user)
          ..where((x) => x.asset?.user?.id).equalTo(idUser);
        final found = await qFind.fetchOne();
        if (found == null) {
          return AppResponse.badRequest(
            message: 'Транзакция не найдена',
          );
        }
        return Response.ok(
          found,
        );
      }
      final qAll = Query<Transaction>(context)
        ..join(object: (x) => x.category)
        ..join(object: (x) => x.asset)
        ..where((x) => x.asset?.user?.id).equalTo(idUser)
        ..where((x) => x.title).contains(query ?? "", caseSensitive: false)
        ..sortBy((x) => x.id, QuerySortOrder.ascending)
        ..offset = (page - 1) * limit
        ..fetchLimit = limit;
      if (categoryId != null) {
        qAll.where((x) => x.category?.id).equalTo(categoryId);
      }
      if (assetId != null) {
        qAll.where((x) => x.asset?.id).equalTo(assetId);
      }
      final found = await qAll.fetch();
      return Response.ok(
        found,
      );
    } catch (exception) {
      return AppResponse.ok(
        message: exception.toString(),
      );
    }
  }

  @Operation.put()
  Future<Response> createTransaction(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Transaction transaction,
  ) async {
    if (transaction.title == null ||
        transaction.amount == null ||
        transaction.asset?.id == null ||
        transaction.category?.id == null) {
      return AppResponse.badRequest(
          message: 'Название, сумма счет,  и категория - обязательные поля');
    }
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qGetAsset = Query<Asset>(context)
        ..where((x) => x.id).equalTo(transaction.asset!.id)
        ..where((x) => x.user?.id).equalTo(userId);
      final asset = await qGetAsset.fetchOne();
      if (asset == null) {
        return AppResponse.badRequest(
          message: "Счет не найден",
        );
      }
      if (transaction.amount! > asset.balance!) {
        return AppResponse.badRequest(
          message: "Недостаточно средств",
        );
      }
      final qCreate = Query<Transaction>(context)
        ..values.title = transaction.title
        ..values.amount = transaction.amount
        ..values.asset?.id = transaction.asset!.id
        ..values.category?.id = transaction.category!.id
        ..values.date = DateTime.now();
      final created = await qCreate.insert();

      final qUpdateAsset = Query<Asset>(context)
        ..values.balance = asset.balance! - transaction.amount!
        ..where((x) => x.id).equalTo(transaction.asset!.id);
      await qUpdateAsset.updateOne();

      final transactionData2 = await (Query<Transaction>(context)
            ..where((x) => x.id).equalTo(created.id)
            ..join(object: (transaction) => transaction.category)
            ..join(object: (transaction) => transaction.asset))
          .fetchOne();
      return Response.ok(transactionData2);
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.post()
  Future<Response> updateTransaction(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Transaction model,
    @Bind.query('id') int id,
  ) async {
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qGet = Query<Transaction>(context)
        ..join(object: (x) => x.category)
        ..join(object: (x) => x.asset).join(object: (x) => x.user)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.asset?.user?.id).equalTo(userId);
      var transaction = await qGet.fetchOne();
      if (transaction == null || transaction.asset?.user?.id != userId) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Транзакция не найдена',
          ),
        );
      }
      final qGetAsset = Query<Asset>(context)
        ..where((x) => x.id).equalTo(transaction.asset?.id)
        ..where((x) => x.user?.id).equalTo(userId);
      final asset = await qGetAsset.fetchOne();
      if (asset == null) {
        return AppResponse.badRequest(
          message: "Счет не найден",
        );
      }
      final qUpdate = Query<Transaction>(context)
        ..where((x) => x.id).equalTo(id);
      if (model.title != null) {
        qUpdate.values.title = model.title;
      }
      final qUpdateAsset = Query<Asset>(context)
        ..where((x) => x.id).equalTo(transaction.asset?.id);
      if (model.amount != null) {
        if (model.amount! > asset.balance! + transaction.amount!) {
          return AppResponse.badRequest(
            message: "Недостаточно средств",
          );
        }
        qUpdate.values.amount = model.amount;
        qUpdateAsset.values.balance =
            asset.balance! + transaction.amount! - model.amount!;
        await qUpdateAsset.updateOne();
      }

      final updated = await qUpdate.updateOne();
      if (updated == null) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Транзакция не найдена',
          ),
        );
      }
      transaction = await qGet.fetchOne();
      transaction!.asset!.user!.removePropertiesFromBackingMap(
        ['accessToken', 'refreshToken'],
      );
      return Response.ok(
        transaction,
      );
    } catch (exception) {
      return AppResponse.ok(
        message: exception.toString(),
      );
    }
  }

  @Operation.delete('id')
  Future<Response> delete(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.path("id") int id,
  ) async {
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qGet = Query<Transaction>(context)
        ..join(object: (x) => x.category)
        ..join(object: (x) => x.asset).join(object: (x) => x.user)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.asset?.user?.id).equalTo(userId);
      final transaction = await qGet.fetchOne();
      if (transaction == null || transaction.asset?.user?.id != userId) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Транзакция не найдена',
          ),
        );
      }
      final qUpdateAsset = Query<Asset>(context)
        ..where((x) => x.id).equalTo(transaction.asset?.id)
        ..values.balance = transaction.asset!.balance! + transaction.amount!;
      await qUpdateAsset.updateOne();
      final qDelete = Query<Transaction>(context)
        ..where((x) => x.id).equalTo(id);
      await qDelete.delete();
      return Response.ok(true);
    } catch (exception) {
      return AppResponse.ok(
        message: exception.toString(),
      );
    }
  }
}
