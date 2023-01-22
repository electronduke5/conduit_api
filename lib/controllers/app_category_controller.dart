import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/category.dart';
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
          ..where((category) => category.id).equalTo(id)
          ..join(object: (user) => user.user);
        final category = await qCategories.fetchOne();
        category!.user!
            .removePropertiesFromBackingMap(['refreshToken', 'accessToken']);
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
          print('filter: ${filter.toString()}');
          qCategories
              .where((category) => category.isDeleted)
              .equalTo(filter == 1 ? true : false);
        }
        else{
            print('filter == null');
            qCategories
                .where((category) => category.isDeleted)
                .equalTo(false);

        }
        final categories = await qCategories.fetch();

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
          message: 'Название категории - обязательное поле');
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
      final categoryData = await context.fetchObjectWithID<Category>(id);
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
      final qFindCategory = Query<Category>(context)
        ..where((category) => category.id).equalTo(categoryId);
      final fCategory = await qFindCategory.fetchOne();

      final qUpdateCategory = Query<Category>(context)
        ..where((category) => category.id).equalTo(categoryId)
        ..values.name = category.name ?? fCategory!.name;

      await qUpdateCategory.updateOne();

      final newCategory = await qFindCategory.fetchOne();
      return Response.ok(newCategory);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }

  @Operation.delete()
  Future<Response> deleteCategory(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query('id') int? id,
  }) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      final qDeleteCategory = Query<Category>(context)
        ..where((category) => category.id).equalTo(id)
        ..where((category) => category.user!.id).equalTo(idUser);
      final category = await qDeleteCategory.fetchOne();
      if (category!.transactions == null) {
        print('Transactions are empty');
        await qDeleteCategory.delete();
        print('Delete success');
      } else {
        qDeleteCategory.values.isDeleted = true;
        await qDeleteCategory.updateOne();
      }
      return AppResponse.ok(message: 'Удаление прошло успешно');
    } on QueryException catch (e) {
      return AppResponse.serverError(e, message: e.message);
    }
  }
}
