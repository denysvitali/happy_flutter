//! Dart-facing sidechain planning entry points.

use crate::sidechain;
use std::time::Instant;

/// Compact metadata for one message-tree node.
///
/// Empty strings represent absent wire fields. The shape is intentionally
/// primitive so FRB can move a batch without encoding dynamic Dart maps.
#[derive(Clone, Debug)]
pub struct SidechainRow {
    pub id: String,
    pub uuid: String,
    pub parent_uuid: String,
    pub parent_tool_use_id: String,
    pub tool_use_id: String,
    pub prompt: String,
    pub agent_id: String,
    pub kind: String,
    pub name: String,
    pub is_sidechain: bool,
    pub is_task_event: bool,
    pub top_level: bool,
    pub ancestor_task_id: String,
    pub root_uuids: Vec<String>,
}

/// Return index-aligned `row -> task id` assignments for top-level rows.
#[flutter_rust_bridge::frb(sync)]
pub fn plan_sidechain_grouping(rows: Vec<SidechainRow>) -> SidechainPlan {
    let start = Instant::now();
    let assignments = sidechain::plan_grouping(&rows);
    SidechainPlan {
        assignments,
        plan_micros: start.elapsed().as_micros().min(u32::MAX as u128) as u32,
    }
}

#[flutter_rust_bridge::frb]
pub struct SidechainPlan {
    pub assignments: Vec<Option<String>>,
    pub plan_micros: u32,
}
