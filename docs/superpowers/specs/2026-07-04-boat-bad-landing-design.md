# Boat 水面 bad landing 回正机制设计

## 背景

目前 `WaterSurface` 在船只进入水面时，会根据船的**全局旋转角**判断是否为安全落水；角度过大时会调用 `Boat.lose_crew(1)`。该设计存在两个问题：

1. 在斜坡关卡中水面本身被旋转，用全局旋转角判断不公平。
2. 船只 bad landing 后没有明确的快速回正表现，玩家容易卡在一个奇怪角度。

本设计将判定改为**船身与水面之间的相对夹角**，并在 bad landing 时让船只快速回正到与水面平行的姿态。

## 目标

- 当船以相对水面过大的角度进入水面时，损失 1 名船员。
- 船只在 bad landing 后短时间内被强扭矩推正，最终与水面平行。
- 判定逻辑与船只受击/回正表现解耦，便于后续扩展音效、动画、无敌帧等。
- 斜坡场景下自动以水面坡度为基准进行判定。

## 核心行为

### 触发条件

- 当 `Boat`（`RigidBody2D`）的碰撞体进入某个 `WaterSurface` 的 `Area2D` 时触发。
- 计算船身方向与水面方向的**相对夹角**。
- 若相对夹角大于 `WaterSurface.safe_landing_angle_degrees`（默认 35°），判定为 bad landing。

### Bad landing 后果

1. `WaterSurface` 发出 `boat_bad_landing(boat, landing_angle_degrees, target_rotation, water_surface)` 信号，供 HUD、音效等观察者监听。
2. 同时，若进入的 body 实现了 `on_bad_landing(angle_degrees, target_rotation, water_surface)` 方法，`WaterSurface` 直接调用该方法通知船只本身。
3. `Boat.on_bad_landing` 中：
   - 调用 `lose_crew(1)`。
   - 进入“强制回正”状态，目标角度为该水面的 `global_rotation`（与水面齐平）。
   - 在 `bad_landing_righting_duration` 秒内，每帧施加一个与当前角度误差成正比、并随时间衰减的强扭矩。
   - 回正期间同时抑制角速度，避免过冲。
4. 从 `WaterSurface._on_body_entered` 中移除直接调用 `body.lose_crew()` 的逻辑，改由 `Boat` 自行处理，实现判定与后果解耦。

### 防连发

- 同一艘船在同一个 `WaterSurface` 内连续进出时，只有在完全离开该水面后再次进入才重新判定。
- 通过 `_last_bad_landing_water` 和 `_last_bad_landing_time` 做最小间隔保护，避免弹跳导致瞬间掉光船员。

## 数据流与信号

### 信号变更

`WaterSurface.boat_bad_landing` 扩展签名：

```gdscript
signal boat_bad_landing(boat: Node2D, landing_angle_degrees: float, target_rotation: float, water_surface: Node2D)
```

其中 `target_rotation` 为该水面希望船回正到的角度，即 `WaterSurface.global_rotation`。

### 相对角度计算

`WaterSurface.get_landing_angle_degrees` 改为：

```gdscript
func get_landing_angle_degrees(body: Node2D) -> float:
    var relative_rotation := wrapf(body.global_rotation - get_boat_target_rotation(), -PI, PI)
    return absf(rad_to_deg(relative_rotation))
```

这样斜坡场景下只要船身与水面平行，相对角度就接近 0°。

### Boat 处理入口

`Boat` 新增公共方法：

```gdscript
func on_bad_landing(angle_degrees: float, target_rotation: float, water_surface: Node2D) -> void
```

`WaterSurface._on_body_entered` 在 bad landing 时直接调用此方法通知船只，同时发出 `boat_bad_landing` 信号供其他系统监听。`Boat.on_bad_landing` 负责掉人和启动回正状态。

## 组件与参数

### WaterSurface 侧

复用已有参数：

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `safe_landing_angle_degrees` | float | 35.0 | 安全落水最大相对角度 |

`unsafe_landing_crew_loss` 从 `WaterSurface` 中移除，船员损失改由 `Boat` 自行处理。

### Boat 侧新增导出变量

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `bad_landing_righting_torque` | float | 80000.0 | 回正基础扭矩 |
| `bad_landing_righting_duration` | float | 0.5 | 强制回正持续秒数 |
| `bad_landing_righting_damping` | float | 3200.0 | 抑制角速度的阻尼项 |
| `bad_landing_min_trigger_interval` | float | 0.3 | 同一水面触发最小间隔 |

### Boat 内部状态

```gdscript
var _righting_timer: float = 0.0
var _righting_target_rotation: float = 0.0
var _last_bad_landing_water: Node2D = null
var _last_bad_landing_time: float = -1000.0
```

## 边界情况与错误处理

1. **船在回正过程中离开水面**：继续完成剩余回正时间，避免一半停在奇怪角度。
2. **船在回正过程中进入另一个水面**：以最新一次 bad landing 的目标角度为准，重置回正计时器。
3. **船已经没有船员**：仍然调用 `lose_crew(1)`（内部 clamp 到 0），仍然执行回正，避免船卡死。
4. **水面被旋转（斜坡）**：相对角度计算已考虑 `get_boat_target_rotation()`，斜坡场景自动正确。
5. **物理步长波动**：回正扭矩在 `_integrate_forces` 里施加，使用 `state.step`，避免帧率影响强度。
6. **重复触发**：通过 `_last_bad_landing_water` 与 `_last_bad_landing_time` 做简单去重保护。

## 测试计划

1. **斜坡关卡测试**
   - 在 `TutorialLevel` 或 `LevelPrototypeSlope` 中，让船以不同角度落入水面。
   - 小角度（<35°）：安全落水，不掉人，船自然漂浮。
   - 大角度（>35°）：掉 1 人，船被快速回正到与水面平行。
   - 验证斜坡场景下使用的是相对角度。

2. **水平水面测试**
   - 放置水平 `WaterSurface`，让船倒扣（约 180°）进入。
   - 应掉 1 人并快速翻回水平。

3. **连发保护测试**
   - 让船在水面边缘快速弹跳。
   - 不应在几帧内连续掉多人。

4. **调试观察**
   - 打开 `BoatRotationDebug` 或 posture log，观察 bad landing 后 `rotation_degrees` 快速收敛到水面角度。

## 后续扩展

- 在 `Boat.on_bad_landing` 中加入船员落水视觉/音效。
- 加入短暂无敌帧，防止回正过程中再次触发 bad landing。
- 根据角度大小分档损失船员（当前固定 1 人）。
