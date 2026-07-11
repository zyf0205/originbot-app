# OriginBot Flutter Android App 开发指南

## 1. 系统概览

OriginBot 机器人基于 RDK X3 开发板运行 TogetheROS (ROS2 Foxy)。本方案通过自建 WebSocket 桥接层，将 ROS2 话题转为 Flutter 可直接消费的 JSON 协议和二进制视频流，**不依赖 rosbridge**。

```
Flutter Android App
   │
   ├── WebSocket ── ws://<机器人IP>:9090/control ── 控制/状态（JSON）
   └── WebSocket ── ws://<机器人IP>:9090/video  ── 视频流（JPEG 二进制帧）
          │
          └── OriginBot 机器人 (10.202.201.32)
               ├── originbot_base  (底盘驱动)
               ├── hobot_usb_cam   (摄像头)
               └── originbot_bridge (WebSocket 桥接节点)
```

### 网络要求

- 手机与机器人必须在**同一局域网**
- 默认通信端口：`9090`（控制+状态）、`9090` 路径 `/video`（视频流）
- 均为 WebSocket 协议，无需 HTTP 服务器

---

## 2. 机器人端部署

### 2.1 编译与安装

```bash
# 在机器人上执行
ssh root@10.202.201.32

# 进入工作空间
cd /home/root/originbot

# 拉取最新代码
git pull

# 编译 originbot_bridge
source /opt/tros/setup.bash
colcon build --packages-select originbot_bridge
source install/setup.bash
```

### 2.2 启动顺序

```bash
# 终端 1：启动底盘 + 摄像头
source /opt/tros/setup.bash
source install/setup.bash
ros2 launch originbot_bringup originbot.launch.py port_name:=ttyS3 use_camera:=true use_imu:=true

# 终端 2：启动 WebSocket 桥接
source /opt/tros/setup.bash
source install/setup.bash
ros2 launch originbot_bridge bridge.launch.py
```

启动成功后终端会显示：
```
[INFO] [originbot_bridge]: WebSocket bridge on ws://0.0.0.0:9090/control  ws://0.0.0.0:9090/video
```

### 2.3 验证

在电脑浏览器打开开发者工具控制台，粘贴以下代码测试：

```javascript
// 测试控制连接
const ws = new WebSocket('ws://10.202.201.32:9090/control');
ws.onopen = () => console.log('控制连接成功');
ws.onmessage = (e) => console.log('收到:', JSON.parse(e.data));
ws.onerror = (e) => console.error('连接失败', e);

// 测试视频连接
const wsVideo = new WebSocket('ws://10.202.201.32:9090/video');
wsVideo.binaryType = 'arraybuffer';
wsVideo.onmessage = (e) => {
  const blob = new Blob([e.data], {type: 'image/jpeg'});
  const url = URL.createObjectURL(blob);
  console.log('视频帧大小:', e.data.byteLength, 'bytes');
};

// 发送前进指令（1秒后自动停止）
ws.onopen = () => {
  ws.send(JSON.stringify({type: 'cmd_vel', linear_x: 0.3, angular_z: 0.0}));
  setTimeout(() => ws.send(JSON.stringify({type: 'stop'})), 1000);
};
```

---

## 3. WebSocket 协议详细定义

### 3.1 控制/状态通道：`ws://<IP>:9090/control`

**JSON 文本帧**。所有消息都以 JSON 字符串形式发送和接收。

#### 3.1.1 连接确认

连接建立后，服务端自动发送：
```json
{
  "type": "connected",
  "msg": "originbot control ready"
}
```

#### 3.1.2 App → 机器人 命令

##### 运动控制 `cmd_vel`

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `type` | string | 必填 | 固定值 `"cmd_vel"` |
| `linear_x` | float | 0.0 | 前进/后退速度，单位 m/s。正值前进，负值后退 |
| `linear_y` | float | 0.0 | 横移速度（差分轮无效，填 0） |
| `angular_z` | float | 0.0 | 转向角速度，单位 rad/s。正值左转，负值右转 |

示例：
```json
{"type": "cmd_vel", "linear_x": 0.3, "angular_z": 0.0}
```

**速度限制**：

| 参数 | 最小值 | 最大值 | 建议值 |
|------|--------|--------|--------|
| `linear_x` | -0.5 | 0.5 | 0.2 ~ 0.3 |
| `angular_z` | -1.0 | 1.0 | 0.3 ~ 0.5 |

**关键约束**：机器人有自动停车机制，超过 **500ms** 未收到 `cmd_vel` 指令会自动停止。App 必须以 **10Hz** 频率持续发送（即使为零速也要发）。

##### 紧急停止 `stop`

```json
{"type": "stop"}
```

等效于 `cmd_vel` 发布全零速度。

##### 查询状态 `get_status`

```json
{"type": "get_status"}
```

返回 `status` 消息（见 3.1.3）。也可不主动查询，服务端每 **0.5 秒** 自动推送。

##### 查询里程计 `get_odom`

```json
{"type": "get_odom"}
```

##### 查询 IMU `get_imu`

```json
{"type": "get_imu"}
```

##### 蜂鸣器控制 `buzzer`

```json
{"type": "buzzer", "on": true}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `on` | bool | `true` 开启蜂鸣器，`false` 关闭 |

##### LED 控制 `led`

```json
{"type": "led", "on": true}
```

#### 3.1.3 机器人 → App 推送消息

##### 机器人状态 `status`

每 0.5 秒自动推送一次，也可主动查询：
```json
{
  "type": "status",
  "battery_voltage": 12.6,
  "buzzer_on": false,
  "led_on": true
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `battery_voltage` | float | 电池电压，单位 V。正常范围 11.0~12.6V，低于 10.5V 需充电 |
| `buzzer_on` | bool | 蜂鸣器当前状态 |
| `led_on` | bool | LED 当前状态 |

##### 里程计 `odom`

每 0.2 秒自动推送一次：
```json
{
  "type": "odom",
  "x": 1.234,
  "y": 0.567,
  "qx": 0.0,
  "qy": 0.0,
  "qz": 0.123,
  "qw": 0.992,
  "vx": 0.25,
  "vy": 0.0,
  "vth": 0.1
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `x` | float | 里程计 X 坐标（米） |
| `y` | float | 里程计 Y 坐标（米） |
| `qx, qy, qz, qw` | float | 姿态四元数 |
| `vx` | float | 当前线速度 m/s |
| `vy` | float | 横向速度（差分轮为 0） |
| `vth` | float | 当前角速度 rad/s |

##### IMU 数据 `imu`

每 0.2 秒自动推送一次：
```json
{
  "type": "imu",
  "roll": 0.5,
  "pitch": -1.2,
  "yaw": 45.3,
  "ax": 0.01,
  "ay": -0.02,
  "az": 9.78,
  "gx": 0.001,
  "gy": -0.002,
  "gz": 0.05
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `roll` | float | 横滚角，单位度 |
| `pitch` | float | 俯仰角，单位度 |
| `yaw` | float | 偏航角，单位度 |
| `ax, ay, az` | float | 线加速度 m/s² |
| `gx, gy, gz` | float | 角速度 rad/s |

##### �误报 `error`

```json
{
  "type": "error",
  "msg": "错误描述信息"
}
```

---

### 3.2 视频通道：`ws://<IP>:9090/video`

**二进制帧**。连接后服务端持续推送 JPEG 帧。

- 每帧为一个 **WebSocket 二进制帧**（binary frame）
- 内容为 **JPEG 编码**的图片数据
- 分辨率 **320×240**（原图 640×480 缩小一半）
- JPEG 压缩质量 **50%**
- 帧率取决于摄像头，默认约 **10~15 fps**
- 单帧大小约 **5~15 KB**

Flutter 端接收方式：
```
收到 WebSocket binary frame → 转为 Uint8List → Image.memory() 显示
```

---

## 4. Flutter App 开发指南

### 4.1 依赖包

```yaml
dependencies:
  flutter:
    sdk: flutter
  web_socket_channel: ^2.4.0
  provider: ^6.1.0
  joystick: ^2.0.0
```

### 4.2 项目结构建议

```
lib/
├── config/
│   └── robot_config.dart          # 机器人 IP、端口等配置
├── models/
│   ├── robot_status.dart          # 电量、LED、蜂鸣器状态
│   ├── odometry.dart              # 里程计数据
│   └── imu_data.dart              # IMU 数据
├── services/
│   ├── control_service.dart       # WebSocket 控制/状态连接
│   └── video_service.dart         # WebSocket 视频流连接
├── screens/
│   ├── home_screen.dart           # 主控页面（摇杆+视频+状态）
│   └── settings_screen.dart       # 设置页面（IP 配置）
├── widgets/
│   ├── joystick_control.dart      # 虚拟摇杆
│   ├── video_view.dart            # 实时视频显示
│   ├── status_panel.dart          # 状态面板（电量、速度）
│   └── connection_indicator.dart  # 连接状态指示
└── main.dart
```

### 4.3 核心逻辑实现要点

#### 4.3.1 控制连接（control_service.dart）

```
1. 连接 ws://<IP>:9090/control
2. 监听 onMessage，按 type 字段分发：
   - "connected"  → 记录连接成功
   - "status"     → 更新状态面板
   - "odom"       → 更新里程计显示
   - "imu"        → 更新 IMU 显示
   - "error"      → 弹窗或日志
3. 发送命令：JSON 序列化后通过 sink.add() 发送
4. 定时器 10Hz 持续发送 cmd_vel（松手时发零速）
5. 断线自动重连（建议 2 秒间隔）
```

#### 4.3.2 视频连接（video_service.dart）

```
1. 连接 ws://<IP>:9090/video
2. 设置 binaryType = 'arraybuffer'
3. 监听 onMessage，data 为二进制帧：
   - 转为 Uint8List
   - Image.memory(bytes) 显示
4. 断线自动重连
```

#### 4.3.3 虚拟摇杆（joystick_control.dart）

```
1. 摇杆拖动事件 → 计算 linear_x 和 angular_z
   - 垂直方向 → linear_x（前后）
   - 水平方向 → angular_z（转向）
2. 摇杆松开 → 立即发送零速
3. 映射关系：
   - 垂直偏移量 [-1, 1] → linear_x [-0.3, 0.3]
   - 水平偏移量 [-1, 1] → angular_z [-0.5, 0.5]
4. 节流：最多每 100ms 发送一次
```

#### 4.3.4 状态面板（status_panel.dart）

```
显示字段：
- 电池电压：battery_voltage V（带颜色指示，绿/黄/红）
- 当前速度：vx m/s, vth rad/s
- 姿态角度：roll, pitch, yaw（度）
- 蜂鸣器状态：开/关（可点击切换）
- LED 状态：开/关（可点击切换）
- 连接状态：控制连接 ●  视频连接 ●
```

### 4.4 权限配置

Android 需要网络权限，在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

### 4.5 注意事项

| 项目 | 说明 |
|------|------|
| 自动停车 | 松开摇杆后必须持续发送零速 `cmd_vel`，500ms 无指令小车自动停 |
| 断线保护 | 控制 WebSocket 断开时，小车会在 0.5 秒后自动停车（安全机制） |
| 线程 | WebSocket 回调在非主线程，更新 UI 需 `setState` 或 `ChangeNotifier` |
| 视频帧率 | 受网络带宽影响，320×240 JPEG 约 10-15fps，够用 |
| 电量告警 | 电压低于 10.5V 时应提示充电 |
| 同网段 | 手机 WiFi 必须与机器人同一局域网 |

---

## 5. 功能验证清单

| # | 验证项 | 方法 | 预期结果 |
|---|--------|------|----------|
| 1 | 控制连接 | App 连接 `ws://IP:9090/control` | 收到 `{"type":"connected"}` |
| 2 | 视频连接 | App 连接 `ws://IP:9090/video` | 收到 JPEG 二进制帧 |
| 3 | 前进 | 发送 `cmd_vel linear_x=0.3` | 小车前进 |
| 4 | 左转 | 发送 `cmd_vel angular_z=0.5` | 小车左转 |
| 5 | 停止 | 发送 `stop` 或零速 | 小车 0.5s 内停止 |
| 6 | 摇杆松开 | 松开摇杆 | 持续发送零速，小车不走 |
| 7 | 电池状态 | 收到 `status` 消息 | `battery_voltage` 有值 |
| 8 | 里程计 | 收到 `odom` 消息 | x, y, vx 有值 |
| 9 | IMU | 收到 `imu` 消息 | roll, pitch, yaw 有值 |
| 10 | 蜂鸣器 | 发送 `buzzer on:true` | 蜂鸣器响 |
| 11 | LED | 发送 `led on:true` | LED 亮 |
| 12 | 断线重连 | 关闭 WiFi 再打开 | App 自动重连 |
| 13 | 视频显示 | 查看视频画面 | 320×240 JPEG 实时画面 |

---

## 6. 常见问题

### Q: 连接不上？

```bash
# 在机器人上检查端口是否监听
ss -tlnp | grep 9090
# 应该看到 0.0.0.0:9090 LISTEN

# 在手机上 ping 机器人
ping 10.202.201.32
```

### Q: 视频画面卡顿？

- 检查 WiFi 信号强度
- 减小 JPEG 质量（修改 ws_server.py 中 `50` 为 `30`）
- 降低分辨率（修改 `320` 为 `160`）

### Q: 小车收到指令不动？

- 检查底盘是否启动（`originbot_base` 节点是否运行）
- 检查串口连接：`ls /dev/ttyS3`
- 检查是否有其他 App 在控制（DDS 话题可能被占用）

### Q: 编译 originbot_bridge 报错？

```bash
# 确保 source 了 tros 环境
source /opt/tros/setup.bash
source install/setup.bash

# 检查依赖
ros2 pkg list | grep originbot_msgs
```

---

## 7. 机器人启动命令速查

```bash
# 最小启动（仅底盘）
ros2 launch originbot_bringup originbot.launch.py port_name:=ttyS3

# 底盘 + IMU
ros2 launch originbot_bringup originbot.launch.py port_name:=ttyS3 use_imu:=true

# 底盘 + 摄像头
ros2 launch originbot_bringup originbot.launch.py port_name:=ttyS3 use_camera:=true

# 完整启动（底盘 + IMU + 摄像头 + LiDAR）
ros2 launch originbot_bringup originbot.launch.py port_name:=ttyS3 use_imu:=true use_camera:=true use_lidar:=true

# 启动 WebSocket 桥接
ros2 launch originbot_bridge bridge.launch.py
```

---

*文档版本：v2.0*
*适用平台：RDK X3 (TogetheROS / ROS2 Foxy)*
*最后更新：2026-07-11*
