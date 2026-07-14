import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'config/ip_history.dart';
import 'models/robot_status.dart';
import 'screens/home_screen.dart';
import 'services/control_service.dart';
import 'services/lidar_service.dart';
import 'services/map_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IpHistory.init();
  runApp(const OriginBotApp());
}

class OriginBotApp extends StatelessWidget {
  const OriginBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RobotStatus()),
        ChangeNotifierProvider(
          create: (ctx) => ControlService(ctx.read<RobotStatus>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LidarService(ctx.read<RobotStatus>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MapService(ctx.read<RobotStatus>()),
        ),
      ],
      child: CupertinoApp(
        title: 'OriginBot',
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: CupertinoColors.systemBlue,
          scaffoldBackgroundColor: Color(0xFFF2F2F7),
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
