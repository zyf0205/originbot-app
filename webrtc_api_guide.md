# OriginBot WebRTC 视频 + WebSocket 控制 接入指南

## 架构变更

### 旧架构
```
摄像头 → mipi_cam → /image_raw → JPEG 压缩 → WebSocket /video → Flutter
```

### 新架构
```
摄像头 → mipi_cam → /image_raw → YUV420p → H.264 编码 → WebRTC → Flutter
```

控制和雷达通道不变，仍然走 WebSocket。

## 端口分配

| 端口 | 协议 | 用途 |
|------|------|------|
| 9090 | WebSocket | 控制指令 + 雷达数据 |
| 9091 | HTTP | WebRTC 信令（SDP 交换） |

## Flutter 端需要做的修改

### 1. 添加依赖

```yaml
dependencies:
  flutter_webrtc: ^0.9.0
  web_socket_channel: ^2.4.0
  http: ^1.1.0
```

### 2. 替换视频模块

**删除**: 原来的 WebSocket 视频接收代码（`/video` 通道）

**新增**: WebRTC 连接流程：
1. `GET http://<机器人IP>:9091/config` → 获取 ICE 配置
2. 创建 `RTCPeerConnection`
3. 添加 `transceiver`（只接收视频）
4. `createOffer()` → 获取 SDP Offer
5. `POST http://<机器人IP>:9091/offer` → 发送 Offer，获取 Answer
6. `setRemoteDescription(answer)`
7. 监听 `onTrack` 事件 → 获取视频流渲染

### 3. 控制和雷达模块

不需要修改，保持原来的 WebSocket 连接方式。

---

## 信令服务器 API (HTTP, 端口 9091)

### GET /config

获取 WebRTC ICE 配置。

**请求**: 无

**响应**:
```json
{
  "iceServers": [
    { "urls": "stun:stun.l.google.com:19302" }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `iceServers` | array | ICE 服务器列表 |
| `iceServers[].urls` | string | STUN/TURN 服务器地址 |

### POST /offer

SDP 交换，完成 WebRTC 握手。

**请求**:
```json
{
  "sdp": "v=0\r\no=- 1234 1 IN IP4 127.0.0.1\r\n...",
  "type": "offer"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `sdp` | string | SDP Offer 字符串 |
| `type` | string | 固定值 `"offer"` |

**响应**:
```json
{
  "sdp": "v=0\r\no=- 5678 1 IN IP4 127.0.0.1\r\n...",
  "type": "answer"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `sdp` | string | SDP Answer 字符串 |
| `type` | string | 固定值 `"answer"` |

### POST /ice

发送 ICE 候选（可选，aiortc 会自动收集）。

**请求**:
```json
{
  "candidate": "candidate:1 1 UDP 2130706431 192.168.1.100 50000 typ host",
  "sdpMid": "0",
  "sdpMLineIndex": 0
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `candidate` | string | ICE 候选字符串 |
| `sdpMid` | string | SDP media ID |
| `sdpMLineIndex` | int | SDP media line 索引 |

**响应**:
```json
{ "ok": true }
```

### GET /status

获取当前连接状态，用于调试。

**响应**:
```json
{
  "connection_state": "connected",
  "ice_state": "connected",
  "video_track_stats": {
    "frame_count": 150,
    "fps": 15,
    "resolution": "640x480"
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `connection_state` | string | 连接状态: `new` / `connecting` / `connected` / `disconnected` / `failed` / `closed` |
| `ice_state` | string | ICE 状态: `new` / `checking` / `connected` / `completed` / `failed` / `disconnected` / `closed` |
| `video_track_stats.frame_count` | int | 已发送帧数 |
| `video_track_stats.fps` | int | 目标帧率 |
| `video_track_stats.resolution` | string | 输出分辨率 |

---

## WebSocket 控制通道 (端口 9090)

连接地址: `ws://<机器人IP>:9090/control`

### 发送指令 (Flutter → Robot)

#### 控制底盘运动
```json
{
  "type": "cmd_vel",
  "linear_x": 0.3,
  "linear_y": 0.0,
  "angular_z": 0.0
}
```

| 字段 | 类型 | 单位 | 说明 |
|------|------|------|------|
| `type` | string | — | 固定值 `"cmd_vel"` |
| `linear_x` | float | m/s | 前进/后退速度，正值前进 |
| `linear_y` | float | m/s | 左右平移速度（麦轮），正值左移 |
| `angular_z` | float | rad/s | 旋转角速度，正值逆时针 |

#### 急停
```json
{ "type": "stop" }
```

#### 查询状态
```json
{ "type": "get_status" }
```

#### 查询里程计
```json
{ "type": "get_odom" }
```

#### 控制蜂鸣器
```json
{ "type": "buzzer", "on": true }
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `on` | bool | `true` 开启，`false` 关闭 |

#### 控制 LED
```json
{ "type": "led", "on": true }
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `on` | bool | `true` 开启，`false` 关闭 |

### 接收数据 (Robot → Flutter)

#### 里程计数据

推送频率: 每 0.2 秒自动推送，或通过 `get_odom` 主动查询。

```json
{
  "type": "odom",
  "x": 0.0464,
  "y": -0.0012,
  "qx": 0.0,
  "qy": 0.0,
  "qz": -0.0323,
  "qw": 0.9995,
  "vx": 0.0,
  "vy": 0.0,
  "vth": 0.0
}
```

| 字段 | 类型 | 单位 | 说明 |
|------|------|------|------|
| `x` | float | m | 沿 x 轴位移，正值前进 |
| `y` | float | m | 沿 y 轴位移，正值左移 |
| `qx` | float | — | 四元数 x 分量，底盘始终为 0 |
| `qy` | float | — | 四元数 y 分量，底盘始终为 0 |
| `qz` | float | — | 四元数 z 分量 |
| `qw` | float | — | 四元数 w 分量 |
| `vx` | float | m/s | 前进/后退线速度 |
| `vy` | float | m/s | 左右平移线速度 |
| `vth` | float | rad/s | 旋转角速度 |

**四元数转 yaw 角**:
```
yaw = atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy² + qz²))
```

#### 机器人状态

推送频率: 每 0.5 秒自动推送，或通过 `get_status` 主动查询。

```json
{
  "type": "status",
  "battery_voltage": 7.4,
  "buzzer_on": false,
  "led_on": false
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `battery_voltage` | float | 电池电压（V） |
| `buzzer_on` | bool | 蜂鸣器当前状态 |
| `led_on` | bool | LED 当前状态 |

#### 连接成功
```json
{
  "type": "connected",
  "msg": "originbot control ready"
}
```

#### 错误
```json
{
  "type": "error",
  "msg": "错误描述"
}
```

---

## WebSocket 雷达通道 (端口 9090)

连接地址: `ws://<机器人IP>:9090/scan`

### 二进制帧格式

推送频率: ~10Hz（与雷达扫描频率一致）

每帧 = Header (12 字节) + Points (N × 8 字节)

#### Header 结构

| 偏移 | 长度 | 类型 | 字段 | 说明 |
|------|------|------|------|------|
| 0 | 4 | uint32 | point_count | 有效点数 N |
| 4 | 4 | float32 | range_min | 最小测距（米） |
| 8 | 4 | float32 | range_max | 最大测距（米） |

#### Points 结构

每个点 8 字节：

| 偏移 | 长度 | 类型 | 字段 | 说明 |
|------|------|------|------|------|
| 12 + i×8 | 4 | float32 | x | X 坐标（米），正前方 |
| 12 + i×8 + 4 | 4 | float32 | y | Y 坐标（米），正左方 |

#### 字节序

所有多字节字段均为 **Little-Endian**（小端序）。

#### 数据示例

```
200 个有效点:
Header:  12 字节
Points:  200 × 8 = 1600 字节
总计:    1612 字节 ≈ 1.6 KB
```

---

## 带宽对比

| 指标 | WebSocket JPEG (旧) | WebRTC H.264 (新) |
|------|---------------------|-------------------|
| 编码格式 | JPEG (每帧独立) | H.264 (帧间预测) |
| 分辨率 | 640×480 | 640×480 |
| 帧率 | 20 fps | 15 fps |
| 码率 | 1-2 Mbps | 300-500 Kbps |
| 延迟 | 100-300 ms | 50-100 ms |
| 带宽节省 | — | **50-70%** |

---

## 部署步骤

### 机器人端

```bash
# SSH 登录机器人
ssh root@10.202.201.32

# 安装依赖
pip3 install aiortc aiohttp av

# 进入工作空间
cd /userdata/dev_ws

# 拉取代码
git pull

# 构建
source /opt/tros/setup.bash
colcon build --packages-select originbot_bridge
source install/setup.bash

# 启动
ros2 launch originbot_bridge bridge.launch.py
```

### Flutter 端

1. 参考上方 API 文档修改代码
2. 添加 `flutter_webrtc`、`web_socket_channel`、`http` 依赖
3. 替换视频接收模块为 WebRTC
4. 控制和雷达模块保持不变

---

## 故障排查

| 问题 | 检查方法 |
|------|----------|
| WebRTC 连接失败 | `curl http://<IP>:9091/status` 查看连接状态 |
| 视频黑屏 | `ros2 topic hz /image_raw` 确认摄像头有数据 |
| 控制无响应 | 检查 WebSocket 是否连接，查看机器人日志 |
| 高延迟 | 检查 WiFi 信号强度，尝试靠近路由器 |
| ICE 状态 failed | 可能是防火墙阻挡 UDP，放行 UDP 端口 |
