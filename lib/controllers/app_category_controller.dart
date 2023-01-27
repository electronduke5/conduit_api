import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/controllers/app_history_controller.dart';
import 'package:conduit_project/models/category.dart';
import 'package:conduit_project/models/history.dart';
import 'package:conduit_project/utils/app_response.dart';

import '../models/user.dart';
import '../utils/app_utils.dart';

class AppCategoryController extends ResourceController {
  AppCategoryController(this.context);

  final ManagedContext context;

  @Operation.get()
  Future<Response> getCategory(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query('id') int? id,
    @Bind.query('filter') int? filter,
    @Bind.query('q') String? query,
    @Bind.query('page') int page = 1,
    @Bind.query('limit') int limit = 10,
  }) async {
    try {
      if (id != null) {
        final qCategories = Query<Category>(context)
          ..where((category) => category.id).equalTo(id);
          //..join(object: (user) => user.user);
        final category = await qCategories.fetchOne();
        category!.removePropertiesFromBackingMap(['user']);
        //category!.user!
          //  .removePropertiesFromBackingMap(['refreshToken', 'accessToken']);
        return Response.ok(category);
      } else {
        final idUser = AppUtils.getIdFromHeader(header);

        final qCategories = Query<Category>(context)
          ..where((a) => a.user?.id).equalTo(idUser)
          ..where((category) => category.name)
              .contains(query ?? '', caseSensitive: false)
          ..offset = (page - 1) * limit
          ..fetchLimit = limit;
        if (filter != null) {
          qCategories
              .where((category) => category.isDeleted)
              .equalTo(filter == 1 ? true : false);
        } else {
          qCategories.where((category) => category.isDeleted).equalTo(false);
        }
        final categories = await qCategories.fetch();
        categories.forEach((element) =>element.removePropertyFromBackingMap('user'));

        return Response.ok(categories);
      }
    } on QueryException catch (e) {
      print('e.message: ${e}');
      print('e.toString(): ${e.toString()}');
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.put()
  Future<Response> createCategory(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Category category,
  ) async {
    if (category.name == null) {
      return AppResponse.badRequest(
        message: 'Название категории - обязательное поле',
      );
    }
    try {
      late final int id;
      final idUser = AppUtils.getIdFromHeader(header);
      final user = await context.fetchObjectWithID<User>(idUser);

      await context.transaction((transaction) async {
        final qCreateCategory = Query<Category>(transaction)
          ..values.name = category.name
          ..values.isDeleted = false
          ..values.user = user;
        final createdCategory = await qCreateCategory.insert();
        id = createdCategory.id!;
      });
      final categoryData = await context.fetchObjectWithID<Category>(id)?..removePropertyFromBackingMap('user');

      AppHistoryController(context).createRecord(
          model: History()
            ..user = user
            ..description =
                AppHistoryController.createDescription('Category', id)
            ..tableName = 'Category');
      return Response.ok(categoryData);
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }

  @Operation.post()
  Future<Response> updateCategory(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Category category,
    @Bind.query('id') int categoryId,
  ) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      final user = await context.fetchObjectWithID<User>(idUser);
      final qFindCategory = Query<Category>(context)
        ..where((category) => category.id).equalTo(categoryId);
      final fCategory = await qFindCategory.fetchOne();

      final qUpdateCategory = Query<Category>(context)
        ..where((category) => category.id).equalTo(categoryId)
        ..values.name = category.name ?? fCategory!.name;

      await qUpdateCategory.updateOne();

      final newCategory = await qFindCategory.fetchOne()?..removePropertyFromBackingMap('user');
      AppHistoryController(context).createRecord(
          model: History()
            ..user = user
            ..description = AppHistoryController.updateDescription('Category', newCategory!.id!)
            ..tableName = 'Category');
      return Response.ok(newCategory);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }

  @Operation.post('id')
  Future<Response> recovery(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path('id') int id) async {
    try {
      final qUpdate = Query<Category>(context)
        ..where((x) => x.id).equalTo(id)
        ..values.isDeleted = false;
      final updated = await qUpdate.updateOne()?..removePropertyFromBackingMap('user');
      return Response.ok(updated);
    } catch (e) {
      return AppResponse.ok(message: e.toString());
    }
  }

  @Operation.delete()
  Future<Response> deleteCategory(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query('id') int? id,
  }) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      final user = await context.fetchObjectWithID<User>(idUser);

      final qDeleteCategory = Query<Category>(context)
        ..where((category) => category.id).equalTo(id)
        ..where((category) => category.user!.id).equalTo(idUser)
        ..join(set: (x) => x.transactions);
      final category = await qDeleteCategory.fetchOne();

      if (category == null) {
        return Response.badRequest(
          body: {"message": "Категория не найдена"},
        );
      }
      if (category.transactions?.isEmpty == true) {
        final qDelete = Query<Category>(context)
          ..where((x) => x.id).equalTo(id);
        await qDelete.delete();
        AppHistoryController(context).createRecord(
            model: History()
              ..user = user
              ..description = AppHistoryController.deleteDescription('Category', id!)
              ..tableName = 'Category');
        return Response.ok(true);
      }

      final qUpdate = Query<Category>(context)
        ..where((x) => x.id).equalTo(id)
        ..values.isDeleted = true;
      final updated = await qUpdate.updateOne()?..removePropertyFromBackingMap('user');
      return Response.ok(updated);
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }
}
