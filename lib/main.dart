import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sdui/sdui.dart';
import 'package:wutsi_wallet/src/access_token.dart';
import 'package:wutsi_wallet/src/device.dart';
import 'package:wutsi_wallet/src/http.dart';

String onboardBaseUrl = 'https://wutsi-onboard-bff-test.herokuapp.com';
String loginBaseUrl = 'https://wutsi-login-bff-test.herokuapp.com';
String homeBaseUrl = 'https://wutsi-home-bff-test.herokuapp.com';

Device device = Device('');
AccessToken accessToken = AccessToken(null, {});
Logger logger = LoggerFactory.create('main');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  device = await Device.get();
  accessToken = await AccessToken.get();
  logger.i('device-id=${device.id} access-token=${accessToken.value}');

  Http.getInstance().interceptors = [
    HttpJsonInterceptor(),
    HttpAuthorizationInterceptor(accessToken),
    HttpTracingInterceptor('wutsi-wallet', device.id),
    HttpInternationalizationInterceptor(),
  ];

  runApp(const WutsiApp());
}

class WutsiApp extends StatelessWidget {
  const WutsiApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wutsi Wallet',
      debugShowCheckedModeBanner: false,
      initialRoute: _initialRoute(),
      routes: {
        '/': (context) =>
            DynamicRoute(provider: HttpRouteContentProvider(homeBaseUrl)),
        '/login': (context) =>
            DynamicRoute(provider: LoginContentProvider(context)),
        '/onboard': (context) =>
            DynamicRoute(provider: HttpRouteContentProvider(onboardBaseUrl)),
      },
    );
  }

  String _initialRoute() {
    String url = '/';
    if (!accessToken.exists()) {
      url = '/onboard';
    } else if (accessToken.expired() == true) {
      logger.i('access_token has expired');
      url = '/login';
    }
    logger.i('initial-route=$url');
    return url;
  }
}

class LoginContentProvider implements RouteContentProvider {
  final BuildContext context;

  const LoginContentProvider(this.context);

  @override
  Future<String> getContent() async =>
      Http.getInstance().post(await _url(), null);

  Future<String> _url() async {
    String url = onboardBaseUrl;
    Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      logger.i('Login with arguments: $args');

      var query = '';
      var phone = args['phone']?.toString().trim();
      if (phone != null && phone.isNotEmpty) {
        query += '&phone=$phone&';

        var title = args['title'];
        if (title != null && title.isNotEmpty) {
          query += '&title=$title';
        }

        var subTitle = args['sub-title'];
        if (subTitle != null && subTitle.isNotEmpty) {
          query += '&sub-title=$subTitle';
        }

        url = loginBaseUrl + "?$query";
      }
    } else {
      if (accessToken.exists()) {
        return loginBaseUrl + "?phone=${accessToken.phoneNumber()}";
      }
    }

    logger.i('login-url=$url');
    return url;
  }
}
