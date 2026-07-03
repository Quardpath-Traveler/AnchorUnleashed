# SlopeWithWater 可复用场景设计

## 背景

现有 `WaterSurface` 是一个独立的水面场景（`scenes/level_parts/WaterSurface.tscn`），它本身不绑定斜面，只是当前在 `LevelPrototypeSlope` 中被作为 `Slope` 的子节点使用并旋转到斜面角度。为了让关卡设计能更快地复用“斜坡 + 水面”的组合，需要封装一个可拖放的 `SlopeWithWater` 场景。

## 目标

- 提供一个可复用的 `SlopeWithWater` 场景，拖入关卡即可用。
- 保留 `WaterSurface` 的物理和视觉行为，不修改其核心脚本。
- 通过 Inspector 暴露关键参数，便于调整斜面几何和水面物理。
- 水面默认参数与当前 `LevelPrototypeSlope` 中实例一致。
- 默认参考船只质量改为 10kg，与 Game 中船只设计保持一致。

## 组件

### 场景结构

```
SlopeWithWater (StaticBody2D)
├── SlopeVisual (Polygon2D)
├── SlopeCollision (CollisionPolygon2D)
└── WaterSurface (instance of scenes/level_parts/WaterSurface.tscn)
```

### 脚本

- 新建 `scripts/level_parts/slope_with_water.gd`，挂载到 `SlopeWithWater` 根节点。
- 类型：`class_name SlopeWithWater extends StaticBody2D`。

## 导出参数

### 斜坡参数

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `slope_length` | float | 560.0 | 斜坡顶部表面长度 |
| `slope_angle_degrees` | float | 14.0 | 斜坡倾斜角度（度） |
| `slope_thickness` | float | 70.0 | 斜坡实体厚度 |
| `slope_color` | Color | Color(0.46, 0.38, 0.28) | 斜坡填充色 |

### 水面参数（透传给 WaterSurface）

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `water_width` | float | 560.0 | 水面宽度 |
| `water_depth` | float | 72.0 | 水面视觉/碰撞深度 |
| `surface_y` | float | -36.0 | 表面波浪基准线本地 Y |
| `wave_amplitude` | float | 9.0 | 主波浪高度 |
| `secondary_wave_amplitude` | float | 4.0 | 次波浪高度 |
| `current_flow_speed` | float | 260.0 | 水流速度/进入冲动 |
| `current_force` | float | 260.0 | 持续水平推力 |
| `buoyancy_force` | float | 5000.0 | 基础浮力 |
| `max_buoyancy_force` | float | 11130.0 | 浮力上限 |
| `reference_boat_mass` | float | 10.0 | 参考船只质量 |

## 数据流

1. `_ready()` 根据 `slope_length`、`slope_angle_degrees`、`slope_thickness` 计算斜坡多边形顶点。
2. 将计算出的多边形同时赋给 `SlopeVisual.polygon` 和 `SlopeCollision.polygon`。
3. 根节点的 `rotation` 保持为 0，通过顶点坐标直接表示斜面几何；水面 `WaterSurface` 子节点被放置并旋转到斜坡顶部表面。
4. `_ready()` 中将所有水面参数同步到 `WaterSurface` 实例的对应导出变量。

## 水面定位

- 水面局部原点位于 `WaterSurface` 的中心。
- 斜坡顶部表面起点假设为 `(-slope_length / 2, 0)`，终点为 `(slope_length / 2, 0)`，沿本地 X 轴水平延伸。
- 水面位置：
  - `position = (0, -surface_y_offset)`，其中 `surface_y_offset` 是水面表面相对其原点的偏移量。
  - 由于 `WaterSurface.surface_y = -36.0`，水面表面在其本地坐标系中位于 y = -36。为让表面与斜坡顶部表面（y = 0）对齐，水面节点位置需要向上偏移 36，即 `position = Vector2(0, 36)`。
- 水面旋转角度：`-deg_to_rad(slope_angle_degrees)`，使水流方向沿斜坡向下。

## 错误处理

- 如果 `WaterSurface` 子节点缺失，在 `_ready()` 中打印错误：`push_error("SlopeWithWater: WaterSurface child instance is missing.")`。
- 斜坡参数限制为合理范围，例如角度限制在 -60 到 60 度，长度和厚度大于 0。

## 测试

1. 在 Godot 中新建临时测试场景。
2. 拖入 `SlopeWithWater.tscn`。
3. 运行场景，驾驶船只从斜坡滑入水面。
4. 验证：
   - 斜坡碰撞正确。
   - 水面动画和浮力生效。
   - 船只沿斜坡下滑后能在水面漂浮并顺流移动。

## 后续扩展

- 如需不同斜面形状（曲线、台阶等），可改用 `B. 组合式` 方案，将 `SlopeVisual` 和 `SlopeCollision` 独立为可替换资源。
