import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'models/robot_status.dart';
import 'screens/home_screen.dart';
import 'services/control_service.dart';
import 'services/video_service.dart';

void main() {
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
          create: (ctx) => VideoService(ctx.read<RobotStatus>()),
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
