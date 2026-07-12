# OriginBot 雷达点云数据接口

## 功能概述

通过 WebSocket 接收机器人激光雷达数据，实时渲染为 2D 点云地图。

## 连接配置

| 配置项 | 值 |
|--------|-----|
| WebSocket 地址 | `ws://<机器人IP>:9090/scan` |
| 数据格式 | 二进制（WebSocket Binary Frame） |
| 推送频率 | ~10Hz（RPLIDAR A1 Standard 模式） |

## 二进制数据格式

每帧数据由 **Header（12 字节）** + **Points（N × 8 字节）** 组成。

### Header 结构（12 字节）

| 偏移 | 长度 | 类型 | 字段 | 说明 |
|------|------|------|------|------|
| 0 | 4 | uint32 | point_count | 有效点数 N |
| 4 | 4 | float32 | range_min | 最小测距（米） |
| 8 | 4 | float32 | range_max | 最大测距（米） |

### Points 结构（每个点 8 字节）

| 偏移 | 长度 | 类型 | 字段 | 说明 |
|------|------|------|------|------|
| 12 + i×8 | 4 | float32 | x | X 坐标（米） |
| 12 + i×8 + 4 | 4 | float32 | y | Y 坐标（米） |

### 字节序

所有多字节字段均使用 **Little-Endian**（小端序）。

### 数据示例

```
200 个有效点的帧：
Header: 12 字节
Points: 200 × 8 = 1600 字节
总计: 1612 字节 ≈ 1.6 KB
```

## 坐标系说明

```
        Y+
        ↑
        |
        |
X-------+-------→ X+
        |
        |
        ↓
        Y-

机器人位于原点 (0, 0)
X 正方向：机器人正前方
Y 正方向：机器人正左方
角度从 X 正方向逆时针增加
```

## Flutter 实现要点

### 1. WebSocket 连接

推荐使用 `web_socket_channel` 包：

```yaml
# pubspec.yaml
dependencies:
  web_socket_channel: ^2.4.0
```

### 2. 接收二进制数据

```dart
final channel = WebSocketChannel.connect(
  Uri.parse('ws://<机器人IP>:9090/scan'),
);

channel.stream.listen((data) {
  if (data is List<int>) {
    final byteData = ByteData.sublistView(Uint8List.fromList(data));
    _parseScanData(byteData);
  }
});
```

### 3. 解析二进制帧

```dart
List<Offset> _parseScanData(ByteData byteData) {
  // 解析 Header
  final pointCount = byteData.getUint32(0, Endian.little);
  final rangeMin = byteData.getFloat32(4, Endian.little);
  final rangeMax = byteData.getFloat32(8, Endian.little);

  // 解析 Points
  final points = <Offset>[];
  for (var i = 0; i < pointCount; i++) {
    final offset = 12 + i * 8;
    final x = byteData.getFloat32(offset, Endian.little);
    final y = byteData.getFloat32(offset + 4, Endian.little);
    points.add(Offset(x, y));
  }

  return points;
}
```

### 4. 点云渲染方案

#### 方案 A：CustomPainter（推荐）

使用 Flutter 的 `CustomPainter` 直接绘制：

```dart
class PointCloudPainter extends CustomPainter {
  final List<Offset> points;
  final double scale;  // 缩放比例，如 50.0 表示 1 米 = 50 像素
  final Offset center; // 画布中心点

  PointCloudPainter({
    required this.points,
    this.scale = 50.0,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.circle;

    for (final point in points) {
      // 坐标变换：ROS 坐标 → 屏幕坐标
      final screenX = center.dx + point.dx * scale;
      final screenY = center.dy - point.dy * scale;  // Y 轴翻转
      canvas.drawCircle(Offset(screenX, screenY), 2.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PointCloudPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
```

#### 方案 B：Flutter GL（3D 渲染）

如果需要 3D 效果或更高性能，可以使用 `flutter_gl` 包进行 OpenGL 渲染。

## 带宽与性能

| 指标 | 值 | 说明 |
|------|-----|------|
| 数据频率 | ~10 Hz | 与雷达扫描频率一致 |
| 每帧点数 | ~400-600 | 过滤无效点后 |
| 单帧大小 | ~1.6 KB | 二进制格式 |
| 带宽需求 | ~16 KB/s | 远低于 JSON 方案 |

## 注意事项

1. **网络延迟**：WiFi 环境下可能有 10-50ms 延迟，点云会略有滞后
2. **无效点过滤**：距离超出 `[range_min, range_max]` 的点已被过滤
3. **坐标变换**：ROS 坐标系 Y 轴正方向为左，屏幕坐标 Y 轴正方向为下，需要翻转
4. **断线重连**：建议实现 WebSocket 断线自动重连机制
5. **帧率控制**：渲染帧率建议 30-60fps，与数据推送频率解耦
