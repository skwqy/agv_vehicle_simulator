# AGV vehicle simulator

Rust **TCP client** that simulates one or more AGVs speaking the **FV2-compatible** `AgvMsgProtocol` protobuf framing expected by schedulers such as YFAOS `AgvSocketServer`. State is pushed as **`StatusMsg`** uplink; downlink handles **`NewTaskMsg`**, **`SegmentMsg`**, **`OperationMsg`**, e-stop, and PLC read/write.

Configuration is via **`config.toml`**. Multiple vehicles share one process (`[settings] robot_count` and serial suffixes).

## Features

- TCP + length-prefixed protobuf frames (CRC optional on uplink body).
- Optional **OpenTCS plant XML** for initial pose and segment-based routes (`[map]`).
- **Multi-vehicle**: distinct wire `agv_id` and serial per instance (`serial_suffix_start + robot_index`).
- Per-vehicle rolling file logs under `logs/<serial>/`; see [Logging](#logging).

## Source layout: PLC simulation (`src/plc`)

[Prost](https://docs.rs/prost)-generated message types live in `crate::scheduling_system` (built from `proto/`). The **`plc`** module holds PLC/FV2 behaviour (`PlcProtobufEngine`), not generic protobuf helpers. Submodules use Rust 2018+ style: **`plc_engine.rs`** + **`plc_engine/`** for children.

```
src/plc.rs                  # re-exports PlcProtobufEngine
src/plc/plc_engine.rs       # PlcProtobufEngine: tick, route motion, handle_downlink dispatch
src/plc/plc_engine/
  route.rs                  # map-backed route chain (ActiveRoute), build_route_segments, point helpers
  encode.rs                 # AckMsg / PLCResponseMsg encoders shared by downlink handlers
  new_task.rs               # NewTaskMsg handling
  segment.rs                # SegmentMsg
  operation.rs              # OperationMsg
  estop.rs                  # EstopMsg
  plc_io.rs                 # PLCWriteMsg / PLCReadMsg → PLCResponseMsg
  status_uplink.rs          # StatusMsg uplink payload bytes (for TCP framing)
```

Other crate modules follow the same pattern where applicable (e.g. `log.rs` + `log/`, `map.rs` + `map/`). Wire encoding stays in `socket/`; `.proto` sources are under `proto/`.

| Path | Role |
|------|------|
| `route.rs` | Geometry and OpenTCS map chain logic, not tied to a single protobuf message name. |
| `encode.rs` | Small `prost::Message` encodes reused by several handlers. |
| `new_task.rs`, `segment.rs`, … | One file per **scheduling_system** downlink message family; `status_uplink.rs` builds periodic **StatusMsg** uplink. |

## Configuration

Use a `config.toml` next to the binary or in the working directory. Example (abbreviated):

```toml
[socket]
host = "127.0.0.1"
port = 8008
connect_timeout_ms = 10000
read_timeout_ms = 0
max_frame_length = 65536
uplink_has_crc = true
reconnect_enabled = true
reconnect_interval_ms = 5000

[vehicle]
serial_number = "Vehicle_"
manufacturer = "defaultManufacturer"

[map]
enabled = true
xml_path = "maps/youle-final-4.xml"
layout_scale_mm = 1.0
layout_flip_y = false
sim_dt_seconds = 0.05
initial_point_name = "Point_1"

[map.name_prefixes]
apply_stripping = true
point_prefix = "Point_"
path_prefix = "Path_"

[settings]
robot_count = 1
serial_suffix_start = 2
map_id = ""
log_max_file_bytes = 10485760
log_max_files = 10

[simulation]
status_interval_ms = 200
status_interval_moving_ms = 100
segment_travel_ms = 2000
default_linear_speed_mm_s = 500
battery_percent = 100
battery_low_threshold_percent = -1
charging = false
initial_point = 0
initial_x_mm = 0.0
initial_y_mm = 0.0
initial_heading_deg = 0.0
```

### `[socket]`

Scheduler **host/port**, frame limits, **uplink CRC**, and reconnect behaviour. Protobuf **`agv_id`** is not configured here; it follows **`[settings] serial_suffix_start + robot_index`** (same number as the serial suffix after `serial_number`).

### `[vehicle]`

Display / log identity: `serial_number` prefix (combined with `[settings] serial_suffix_start` per robot).

### `[map]` (optional)

OpenTCS XML path, layout scale/flip, simulation time step, optional **initial point name** for pose. `[map.name_prefixes]` controls point/path name stripping for map lookups.

### `[settings]`

Fleet size (`robot_count`), **`serial_suffix_start`** (first serial suffix and protobuf **`agv_id`** for robot 0; robot *i* uses `serial_suffix_start + i`), optional `map_id` (reserved for shared configs), and log rotation (`log_max_file_bytes`, `log_max_files`).

### `[simulation]`

Status cadence, segment timing fallback, speeds, battery/charge flags, and default initial pose when the map is disabled or missing.

## Docker

The repo may include a `Dockerfile` and Compose files to run the binary in a container. Mount your **`config.toml`** so the process can reach your **scheduler TCP** endpoint (adjust `host` / `port` for Docker networking, e.g. host gateway on Linux).

## Requirements

- **Rust** (see [rustup](https://www.rust-lang.org/tools/install)).
- A reachable **TCP server** implementing the expected protobuf framing (the scheduler / bridge under test).

## Getting started

```bash
cargo build --release
# Edit config.toml: socket host/port, map path, fleet size, etc.
cargo run --release
```

## Usage

Each simulated vehicle opens a **TCP connection** to the configured address, sends **`StatusMsg`** on a timer (and after connect), and replies to downlink frames (`AckMsg`, `PLCResponseMsg`, …) according to `proto/AgvMsgProtocol.proto`. Use your scheduler’s documentation or logs to verify `agv_id` and serial numbers match the fleet configuration.

## Logging

Structured logging goes to **stderr** and, per vehicle, to **`logs/<vehicle serial>/vehicle.log`** (with size-based rotation). Rotation defaults: **10 MiB** per file, **10** files (`log_max_file_bytes`, `log_max_files` in `[settings]`). Verbosity: `RUST_LOG` (e.g. `RUST_LOG=debug`).

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

## Reference

| Resource | URL |
|----------|-----|
| **OpenTCS** (plant XML / maps) | https://github.com/openTCS/opentcs |
