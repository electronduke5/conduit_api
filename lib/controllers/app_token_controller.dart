import 'dart:async';
import 'dart:io';
import 'package:conduit/conduit.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

import '../utils/app_const.dart';
import '../utils/app_response.dart';

class AppTokenController extends Controller {
  @override
  FutureOr<RequestOrResponse?> handle(Request request){
    try{
      //Получаем токен из header запроса
      final header = request.raw.headers.value(HttpHeaders.authorizationHeader);
      //Из header получаем токен
      final token = const AuthorizationBearerParser().parse(header);

      //Получаем jwtClaim для проверки токена
      final jwtClaim = verifyJwtHS256Signature(token?? '', AppConst.secretKey);
      //Валидируем токен
      jwtClaim.validate();
      return request;
    } on JwtException catch (e){
      return AppResponse.serverError(e, message: e.message);
    }
  }
}
