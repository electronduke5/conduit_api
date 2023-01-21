import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/user.dart';
import 'package:conduit_project/utils/app_utils.dart';

import '../utils/app_response.dart';

class AppUserController extends ResourceController {
  AppUserController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> getProfile(
      @Bind.header(HttpHeaders.authorizationHeader) String header) async {
    try {
      //TODO: Убрать substring (в Postman в начале токена написано Bearer *токен*)
      header = header.substring(7);
      //Получаем id пользователя
      final id = AppUtils.getIdFromToken(header);

      final user = await managedContext.fetchObjectWithID<User>(id);
      //Удаляем ненужные параметры для красивого вывода данных пользователя
      user!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);
      return AppResponse.ok(
          message: 'Успешное получение профиля', body: user.backing.contents);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения профиля');
    }
  }

  @Operation.post()
  Future<Response> updateProfile(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() User user) async {
    try {
      //TODO: Убрать substring (в Postman в начале токена написано Bearer *токен*)
      header = header.substring(7);
      final id = AppUtils.getIdFromToken(header);
      final fUser = await managedContext.fetchObjectWithID<User>(id);
      final qUpdateUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id)
        ..values.userName = user.userName ?? fUser!.userName
        ..values.email = user.email ?? fUser!.email;

      //Вызов функции для обновления данных
      await qUpdateUser.updateOne();

      final newUser = await managedContext.fetchObjectWithID<User>(id);
      newUser!.removePropertiesFromBackingMap(['refreshToken', 'accessToken']);

      return AppResponse.ok(
        message: 'Успешное обновление данных',
        body: newUser.backing.contents,
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }

  @Operation.put()
  Future<Response> updatePassword(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query('newPassword') String newPassword,
    @Bind.query('oldPassword') String oldPassword,
  ) async {
    try {
      //TODO: Убрать substring (в Postman в начале токена написано Bearer *токен*)
      header = header.substring(7);
      final id = AppUtils.getIdFromToken(header);
      final qFindUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id)
        ..returningProperties(
          (property) => [
            property.salt,
            property.hashPassword,
          ],
        );

      final fUser = await qFindUser.fetchOne();

      //Создаем hash старого пароля
      final oldHashPassword =
          generatePasswordHash(oldPassword, fUser!.salt ?? '');

      //Проверяем старый пароль с паролем в БД
      if (oldHashPassword != fUser.hashPassword) {
        return AppResponse.badRequest(
          message: 'Неверный старый пароль',
        );
      }

      //Создаем хеш нового пароля
      final newHashPassword =
          generatePasswordHash(newPassword, fUser.salt ?? '');

      //Создаем запрос на обновление пароля
      final qUpdateUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id)
        ..values.hashPassword = newHashPassword;

      await qUpdateUser.fetchOne();
      return AppResponse.ok(body: 'Пароль успешно обновлен');
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления пароля');
    }
  }
}
