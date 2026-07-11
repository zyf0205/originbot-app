# OriginBot Flutter 遥控 App

OriginBot 机器人（RDK X3 / TogetheROS）的 Flutter Android 遥控应用，通过 WebSocket 直连机器人端桥接节点，提供实时视频、运动控制与状态显示。不依赖 rosbridge。

## 功能

- **实时视频**：WebSocket 二进制 JPEG 帧流，`Image.memory` 渲染
- **运动控制**：虚拟摇杆 → `cmd_vel`（10Hz 持续发送，松手归零）
- **速度限制**：线速度 / 角速度上限滑块可调
- **状态显示**：电池电压（含低电告警）、里程计速度（vx / vth）
- **外设控制**：蜂鸣器、LED 一键开关，带按压反馈
- **连接管理**：IP 历史持久化（重启保留），双通道独立状态指示

## 通信协议

App 与机器人通过两个 WebSocket 通道通信（手机与机器人需在同一局域网）：

| 通道 | 地址 | 帧格式 | 用途 |
|------|------|--------|------|
| 控制 / 状态 | `ws://<机器人IP>:9090/control` | JSON 文本 | 发送命令、接收状态 |
| 视频流 | `ws://<机器人IP>:9090/video` | 二进制 JPEG 帧 | 实时画面 |

关键命令：`cmd_vel`（运动）、`stop`（停止）、`buzzer`/`led`（外设）、`status`/`odom`（状态推送）。

完整协议定义、机器人端部署与验证流程见 [ORIGINBOT_FLUTTER_APP_DEV.md](./ORIGINBOT_FLUTTER_APP_DEV.md)。

## 目录结构

```
lib/
├── main.dart                      # 入口，注册 Provider 并初始化 IP 历史
├── config/
│   └── ip_history.dart             # IP 历史（SharedPreferences 持久化）
├── models/
│   └── robot_status.dart           # 全局状态（连接 / 电池 / 里程计 / 外设）
├── screens/
│   └── home_screen.dart            # 主界面（连接卡片 + 视频 + 状态 + 控制区）
├── services/
│   ├── control_service.dart         # WebSocket 控制服务（9090/control）
│   └── video_service.dart           # WebSocket 视频服务（9090/video）
└── widgets/
    ├── connection_indicator.dart     # 导航栏双圆点连接指示器
    ├── joystick_control.dart          # 虚拟摇杆
    ├── speed_sliders.dart            # 线速度 / 角速度上限滑块
    ├── status_panel.dart             # 电池、里程、蜂鸣器 / LED
    └── video_view.dart              # 视频渲染 + 占位 / 错误状态
```

## 构建与运行

```bash
# 安装依赖
flutter pub get

# 连接 Android 设备后运行
flutter run
```

## 依赖

| 依赖 | 用途 |
|------|------|
| `provider` | 状态管理 |
| `web_socket_channel` | WebSocket 通信（控制 + 视频） |
| `flutter_joystick` | 虚拟摇杆 |
| `shared_preferences` | IP 历史持久化 |

## 权限

Android 需在 `android/app/src/main/AndroidManifest.xml` 配置网络权限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

## 使用

1. 启动机器人端桥接节点（见开发指南）
2. 手机连接与机器人相同的 WiFi
3. App 输入机器人 IP，点击右上角电源图标连接
4. 摇杆控制移动，滑块调节速度上限，状态面板查看电量 / 速度并控制蜂鸣器 / LED

## 注意事项

- 机器人有 500ms 自动停车机制，App 以 10Hz 持续发送 `cmd_vel`（含零速）
- 电池电压低于 10.5V 时显示红色告警，需充电
- 视频分辨率 320×240 JPEG，帧率受网络影响（约 10~15fps）
