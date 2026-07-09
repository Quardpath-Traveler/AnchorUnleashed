# 锚抛物线投掷与松弛铁链测试验证

## 功能范围

本测试用于验证锚抛出逻辑从直线飞行改为抛物线飞行后，投掷过程、最大长度限制、日志输出和铁链视觉都符合预期。

需要重点验证：

- 锚从瞄准状态进入飞行状态后，不再沿直线匀速移动。
- 锚的飞行轨迹有明显弧度，并出现上升后回落的抛物线趋势。
- 锚飞行时仍然受最大长度限制，超过最大长度会收回。
- 连接锚和船的铁链不再是两点直线，而是由多段点组成。
- 铁链中间段沿重力方向下垂，表现为松松垮垮的状态。
- 调试日志能输出轨迹、速度、绳长、状态和铁链点数量，便于人工复查。

## 前置工作

- [x] 阅读 `docs/testing/new-feature-testing.md`，按“测试点、日志、测试场景、运行验证”的流程执行。
- [x] 在 `scripts/mechanics/anchor.gd` 中保留可控调试日志：
  - `debug_logging_enabled`
  - `debug_log_interval_seconds`
  - `anchor_log_prefix`
  - `get_anchor_log_data()`
  - `emit_anchor_log()`
- [x] 搭建最小回归场景：
  - `debug/AnchorThrowRegression.tscn`
  - `debug/anchor_throw_regression.gd`
- [x] 固定测试初始状态：
  - socket 初始位置：`Vector2(120.0, 260.0)`
  - 投掷目标偏移：`Vector2(380.0, -180.0)`
  - 最大长度：`720.0`
  - 采样帧数：`24`

## 自动验证项

### 结构测试

运行：

```bash
python3 -m unittest tests/scaffold/test_project_structure.py
```

验证内容：

- `Anchor` 暴露抛物线投掷参数：
  - `launch_arc_height`
  - `launch_gravity_scale`
- `Anchor` 暴露松弛铁链参数：
  - `rope_visual_segments`
  - `rope_slack_pixels`
- `Anchor` 提供调试日志数据：
  - `get_anchor_log_data()`
  - `emit_anchor_log()`
- 锚飞行逻辑使用 `_get_parabolic_flight_position()`。
- 铁链视觉使用 `_build_slack_rope_points()` 和 `_get_rope_slack_offset()`。
- 回归场景 `debug/AnchorThrowRegression.tscn` 存在，并启用 `fail_on_regression = true`。

### Godot 回归场景

通过 Godot MCP 运行 `debug/AnchorThrowRegression.tscn`，读取 debug output 并在验证结束后停止项目实例。

验证内容：

- `arc_deviation >= min_arc_deviation`
  - 用于确认锚轨迹不再是直线。
- `has_parabolic_apex == true`
  - 用于确认轨迹出现最高点，并且后段有回落趋势。
- `chain_point_count >= min_chain_points`
  - 用于确认铁链由多段点组成，不是简单两点直线。
- `chain_slack >= min_chain_slack`
  - 用于确认铁链中间段沿重力方向下垂。
- `max_sampled_speed <= max_sampled_speed`
  - 用于确认投掷速度没有异常飙高。
- `log_has_required_fields == true`
  - 用于确认日志包含状态、位置、速度、时间、绳长和铁链点数量。
- `failed == false`
  - 用于确认本次回归场景通过。

## 人工观察日志

运行回归场景时应至少看到两类日志：

```text
ANCHOR_DEBUG {...}
ANCHOR_THROW_RESULT {...}
```

`ANCHOR_DEBUG` 需要包含：

- `state`
- `global_position`
- `throw_origin_global`
- `launch_target_global`
- `launch_velocity`
- `launch_initial_velocity`
- `launch_elapsed_seconds`
- `rope_length`
- `rope_point_count`

`ANCHOR_THROW_RESULT` 需要重点检查：

- `recalled_early` 为 `false`。
- `arc_deviation` 大于阈值。
- `has_parabolic_apex` 为 `true`。
- `chain_point_count` 大于等于阈值。
- `chain_slack` 大于阈值。
- `failed` 为 `false`。

## 真实场景回归

自动回归场景通过后，还需要在真实游戏场景中试玩：

- 从主场景进入关卡后，按住锚键进入瞄准。
- 松开锚键后，锚按抛物线飞出。
- 锚飞行时铁链明显下垂，不是绷直线。
- 锚达到最大长度后能自动收回。
- 锚勾住 hook point 后，船的摆荡逻辑仍能正常工作。
- 再次按锚键能收回锚，收回后能再次投掷。
- 暂停、继续、重新开始后，锚状态不会卡死。

## 当前验证结果

已执行：

```bash
python3 -m unittest tests/scaffold/test_project_structure.py
```

结果：

```text
Ran 11 tests in 0.007s
OK
```

已执行：

```text
Godot MCP run_project scene=debug/AnchorThrowRegression.tscn
```

结果：

```text
ANCHOR_THROW_RESULT {"arc_deviation":32.507,"chain_point_count":9,"chain_slack":7.489,"failed":false,"frames":24,"has_parabolic_apex":true,"log_has_required_fields":true,"max_sampled_speed":689.248,"recalled_early":false}
```

同时执行了蓄力投掷回归场景，避免抛物线和松弛铁链改动破坏锚的蓄力速度验证：

```text
Godot MCP run_project scene=debug/AnchorChargeRegression.tscn
```

结果：

```text
ANCHOR_CHARGE_RESULT {"failed":false,"high_charge_ratio":1.0,"high_direction_error_degrees":0.0,"high_speed":440.0,"low_charge_ratio":0.0,"low_direction_error_degrees":0.0,"low_speed":260.0,"speed_delta":180.0}
```
