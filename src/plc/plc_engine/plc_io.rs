//! Downlink: `PLCWriteMsg` / `PLCReadMsg` → `PLCResponseMsg`.

use prost::Message;

use super::encode;
use super::PlcProtobufEngine;
use crate::scheduling_system::{PlcReadMsg, PlcWriteMsg};

pub(super) fn handle_write(eng: &mut PlcProtobufEngine, payload: &[u8]) -> Option<Vec<(String, Vec<u8>)>> {
    let msg = PlcWriteMsg::decode(payload).ok()?;
    Some(vec![(
        "PLCResponseMsg".into(),
        encode::plc_response(msg.frame_id, eng.agv_id, msg.task_id, 1, 0, &[]),
    )])
}

pub(super) fn handle_read(eng: &mut PlcProtobufEngine, payload: &[u8]) -> Option<Vec<(String, Vec<u8>)>> {
    let msg = PlcReadMsg::decode(payload).ok()?;
    Some(vec![(
        "PLCResponseMsg".into(),
        encode::plc_response(msg.frame_id, eng.agv_id, msg.task_id, 0, 0, &[]),
    )])
}
