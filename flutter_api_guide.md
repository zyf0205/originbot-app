# OriginBot odom 数据接口

## 数据来源

通过控制通道 `ws://<机器人IP>:9090/control` 接收，每 0.2 秒自动推送一次。

也可主动查询：

```json
{"type": "get_odom"}
```

## 数据格式

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

## position（位置）

机器人在 odom 坐标系中的位置，单位为**米 (m)**。

| 字段 | 类型 | 说明 |
|------|------|------|
| `x` | float | 沿 x 轴位移，正值为前进 |
| `y` | float | 沿 y 轴位移，正值为左移 |

示例：`x: 0.0464` 表示前进了 4.6 厘米。

## orientation（朝向）

四元数表示机器人朝向。平面底盘只有 yaw 旋转，所以 `qx` 和 `qy` 始终为 0。

| 字段 | 类型 | 说明 |
|------|------|------|
| `qx` | float | 四元数 x 分量，始终为 0 |
| `qy` | float | 四元数 y 分量，始终为 0 |
| `qz` | float | 四元数 z 分量 |
| `qw` | float | 四元数 w 分量 |

**四元数转 yaw 角（Dart）**：

```dart
double quaternionToYaw(double qx, double qy, double qz, double qw) {
  double siny = 2.0 * (qw * qz + qx * qy);
  double cosy = 1.0 - 2.0 * (qy * qy + qz * qz);
  return atan2(siny, cosy);  // 返回弧度
}

// 弧度转角度
double yawDeg = quaternionToYaw(qx, qy, qz, qw) * 180 / pi;
```

示例：`qz: -0.0323, qw: 0.9995` → yaw ≈ -3.7°（向左偏了 3.7 度）

## twist（速度）

| 字段 | 类型 | 单位 | 说明 |
|------|------|------|------|
| `vx` | float | m/s | 前进/后退线速度 |
| `vy` | float | m/s | 左右平移线速度（麦轮底盘） |
| `vth` | float | rad/s | 旋转角速度 |
