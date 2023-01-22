import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/controllers/app_asset_controller.dart';
import 'package:conduit_project/controllers/app_auth_controllers.dart';
import 'package:conduit_project/controllers/app_category_controller.dart';
import 'package:conduit_project/controllers/app_token_controller.dart';
import 'package:conduit_project/controllers/app_user_controller.dart';

class AppService extends ApplicationChannel {
  late final ManagedContext managedContext;

  @override
  Future prepare() {
    final persistentStore = _initDatabase();
    managedContext = ManagedContext(
        ManagedDataModel.fromCurrentMirrorSystem(), persistentStore);
    return super.prepare();
  }

  @override
  Controller get entryPoint => Router()
    ..route('token/[:refresh]').link(
      () => AppAuthController(managedContext),
    )
    ..route('user')
        .link(AppTokenController.new)!
        .link(() => AppUserController(managedContext))
    ..route('asset')
        .link(AppTokenController.new)!
        .link(() => AppAssetController(managedContext))
    ..route('category')
        .link(AppTokenController.new)!
        .link(() => AppCategoryController(managedContext));

  PersistentStore _initDatabase() {
    final username = Platform.environment["DB_USERNAME"] ?? 'postgres';
    final password = Platform.environment["DB_PASSWORD"] ?? 'admin';
    final host = Platform.environment["DB_HOST"] ?? '127.0.0.1';
    final port = int.parse(Platform.environment["DB_PORT"] ?? '5432');
    final database = Platform.environment["DB_DATABASE"] ?? 'accounting';
    return PostgreSQLPersistentStore.fromConnectionInfo(
        username, password, host, port, database);
  }
}
