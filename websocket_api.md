# OriginBot 上位机 WebSocket 接口文档

## 概览

机器人运行 `originbot_bridge` 节点后，在 **9090 端口** 提供三个 WebSocket 通道：

| 通道 | 地址 | 方向 | 数据类型 | 用途 |
|------|------|------|----------|------|
| `/control` | `ws://<机器人IP>:9090/control` | 双向 | JSON 文本 | 发送指令、接收里程计和状态 |
| `/scan` | `ws://<机器人IP>:9090/scan` | 下行 | 二进制 | 实时激光雷达点云 |
| `/map` | `ws://<机器人IP>:9090/map` | 下行 | 二进制 | 栅格地图（建图时推送） |

---

## 1. `/control` — 控制通道

### 1.1 连接成功

连接后服务端立即推送：

```json
{"type": "connected", "msg": "originbot control ready"}
```

### 1.2 服务端推送（下行）

#### 里程计（每 200ms 推送）

```json
{
  "type": "odom",
  "x": 1.2345,
  "y": -0.5678,
  "qx": 0.0,
  "qy": 0.0,
  "qz": 0.7071,
  "qw": 0.7071,
  "vx": 0.2,
  "vy": 0.0,
  "vth": 0.5
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `x`, `y` | float | 机器人位置（米），odom 坐标系 |
| `qx`, `qy`, `qz`, `qw` | float | 姿态四元数 |
| `vx`, `vy` | float | 线速度（m/s） |
| `vth` | float | 角速度（rad/s） |

#### 机器人状态（每 500ms 推送）

```json
{
  "type": "status",
  "battery_voltage": 12.45,
  "buzzer_on": false,
  "led_on": true
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `battery_voltage` | float | 电池电压（V） |
| `buzzer_on` | bool | 蜂鸣器状态 |
| `led_on` | bool | LED 状态 |

### 1.3 客户端指令（上行）

#### 速度控制

```json
{"type": "cmd_vel", "linear_x": 0.2, "linear_y": 0.0, "angular_z": 0.5}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `linear_x` | float | 前进速度（m/s），正值前进 |
| `linear_y` | float | 横向速度（m/s），底盘不支持则为 0 |
| `angular_z` | float | 旋转角速度（rad/s），正值逆时针 |

#### 急停

```json
{"type": "stop"}
```

#### 主动查询

```json
{"type": "get_status"}
{"type": "get_odom"}
```

#### 蜂鸣器 / LED

```json
{"type": "buzzer", "on": true}
{"type": "led", "on": false}
```

---

## 2. `/scan` — 激光雷达点云通道

纯下行二进制通道，每收到一帧 LaserScan 即推送。

### 二进制帧格式

```
┌─────────────────────────────────────────┐
│ Header (12 bytes)                       │
│   point_count  : uint32 (little-endian) │
│   range_min    : float32                │
│   range_max    : float32                │
├─────────────────────────────────────────┤
│ Point[0] (8 bytes)                      │
│   x : float32                           │
│   y : float32                           │
├─────────────────────────────────────────┤
│ Point[1] (8 bytes)                      │
│   ...                                   │
├─────────────────────────────────────────┤
│ Point[N-1] (8 bytes)                    │
└─────────────────────────────────────────┘
```

总长度 = `12 + point_count * 8` 字节。

坐标系：以雷达中心为原点，x 轴朝前，y 轴朝左（ROS 标准）。单位：米。

### 解析示例（Dart）

```dart
import 'dart:typed_data';

void parseScan(ByteData data) {
  int count = data.getUint32(0, Endian.little);
  double rangeMin = data.getFloat32(4, Endian.little);
  double rangeMax = data.getFloat32(8, Endian.little);

  List<Point> points = [];
  int offset = 12;
  for (int i = 0; i < count; i++) {
    double x = data.getFloat32(offset, Endian.little);
    double y = data.getFloat32(offset + 4, Endian.little);
    points.add(Point(x, y));
    offset += 8;
  }
}
```

---

## 3. `/map` — 栅格地图通道

纯下行二进制通道，建图时由 Cartographer 产生，**每 2 秒推送一次**。新连接时如果有缓存地图，立即推送一次。

### 二进制帧格式

```
┌──────────────────────────────────────────────────┐
│ JSON Header (UTF-8, 以 \x00 结尾)                │
│                                                  │
│ {                                                │
│   "width": 400,         // 栅格宽度（列数）       │
│   "height": 400,        // 栅格高度（行数）       │
│   "resolution": 0.05,   // 每格边长（米）         │
│   "origin_x": -10.0,    // 地图原点 x（米）       │
│   "origin_y": -10.0     // 地图原点 y（米）       │
│ }\x00                                            │
├──────────────────────────────────────────────────┤
│ Grid Data (width * height bytes)                 │
│                                                  │
│ 每字节表示一个栅格的占用概率：                     │
│   0       = 完全空闲                             │
│   1~99    = 占用概率                             │
│   100     = 完全占用（障碍物）                    │
│   255     = 未知区域                             │
└──────────────────────────────────────────────────┘
```

### 坐标映射

栅格索引 `(col, row)` 对应真实世界坐标：

```
world_x = origin_x + col * resolution
world_y = origin_y + row * resolution
```

数据排列：**行优先**（row-major），第 0 行第 0 列在数据起始位置。即：

```
index = row * width + col
```

### 解析示例（Dart）

```dart
import 'dart:convert';
import 'dart:typed_data';

class OccupancyMap {
  final int width;
  final int height;
  final double resolution;
  final double originX;
  final double originY;
  final Uint8List grid;

  OccupancyMap({
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    required this.grid,
  });

  int cellAt(int col, int row) => grid[row * width + col];

  static OccupancyMap parse(Uint8List data) {
    int nullIdx = data.indexOf(0);
    String headerStr = utf8.decode(data.sublist(0, nullIdx));
    Map<String, dynamic> header = jsonDecode(headerStr);

    Uint8List grid = data.sublist(nullIdx + 1);

    return OccupancyMap(
      width: header['width'],
      height: header['height'],
      resolution: header['resolution'],
      originX: header['origin_x'],
      originY: header['origin_y'],
      grid: grid,
    );
  }
}
```

### 渲染建议

- **空闲（0）**：白色/透明
- **占用（100）**：黑色
- **概率（1~99）**：灰色渐变，值越大越深
- **未知（255）**：浅灰色（#E0E0E0）

可用 `Canvas.drawImage` 或自定义 `CustomPainter` 将 grid 渲染为像素图。建图过程中地图的 `width`/`height` 会动态增长，每次收到新帧需重建画布。

---

## 4. 建图流程

```
1. 启动底盘+雷达:  ros2 launch originbot_bringup originbot.launch.py use_lidar:=true
2. 启动建图:       ros2 launch originbot_navigation cartographer.launch.py
3. 启动桥接:       ros2 run originbot_bridge ws_server
4. 上位机连接:
   - ws://<IP>:9090/control  → 收发控制和状态
   - ws://<IP>:9090/scan     → 接收实时点云
   - ws://<IP>:9090/map      → 接收栅格地图（2秒/帧）
5. 遥控机器人走动建图（通过 control 通道发送 cmd_vel）
6. 保存地图:       ros2 run nav2_map_server map_saver_cli -f ~/my_map
```

---

## 5. 连接示意图

```
Flutter App                         Robot (10.202.201.32)
┌─────────────┐                     ┌─────────────────────┐
│ control ws  │◄──── JSON ────────►│  /control (9090)    │
│             │─── cmd_vel ────────►│    → /cmd_vel       │
│             │◄── odom/status ────│    ← /odom, /status │
├─────────────┤                     ├─────────────────────┤
│ scan ws     │◄── binary ─────────│  /scan (9090)       │
│             │    点云数据         │    ← /scan          │
├─────────────┤                     ├─────────────────────┤
│ map ws      │◄── binary ─────────│  /map (9090)        │
│             │    栅格地图         │    ← /map           │
└─────────────┘                     └─────────────────────┘
```
