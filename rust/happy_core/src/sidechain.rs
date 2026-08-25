//! Compact sidechain-parent planning for the message grouper.
//!
//! Dart owns the dynamic message maps and the final child-list mutation. Rust
//! owns the repeated identity indexing and parent-chain walk. Keeping this
//! boundary as a plan (`row index -> task id`) means a missing or faulty
//! native core can fall back to the existing Dart grouper without changing
//! message identity or ordering.

use std::collections::{HashMap, HashSet};

use crate::api::sidechain_api::SidechainRow;

fn is_agent_container(row: &SidechainRow) -> bool {
    row.kind == "tool-call"
        && matches!(row.name.as_str(), "Task" | "Agent" | "Workflow")
        && !row.id.is_empty()
}

fn add_if_absent(map: &mut HashMap<String, String>, key: &str, value: &str) {
    if !key.is_empty() {
        map.entry(key.to_owned())
            .or_insert_with(|| value.to_owned());
    }
}

fn add_overwrite(map: &mut HashMap<String, String>, key: &str, value: &str) {
    if !key.is_empty() {
        map.insert(key.to_owned(), value.to_owned());
    }
}

fn walk_chain_to_task(
    start: &str,
    uuid_to_task: &mut HashMap<String, String>,
    sidechain_by_uuid: &HashMap<String, &SidechainRow>,
) -> Option<String> {
    if start.is_empty() {
        return None;
    }

    let mut current = start.to_owned();
    let mut walked: Vec<String> = Vec::new();
    let mut visited = HashSet::new();

    while !current.is_empty() && visited.insert(current.clone()) {
        if let Some(task_id) = uuid_to_task.get(&current).cloned() {
            for uuid in walked {
                add_overwrite(uuid_to_task, &uuid, &task_id);
            }
            return Some(task_id);
        }

        walked.push(current.clone());
        let ancestor = sidechain_by_uuid.get(&current)?;
        if ancestor.parent_uuid.is_empty() {
            return None;
        }
        current = ancestor.parent_uuid.clone();
    }

    None
}

fn resolve_root(
    row: &SidechainRow,
    task_by_identity: &HashMap<String, String>,
    prompt_to_task: &HashMap<String, String>,
    uuid_to_task: &mut HashMap<String, String>,
    sidechain_by_uuid: &HashMap<String, &SidechainRow>,
    agent_to_task: &HashMap<String, String>,
) -> Option<String> {
    task_by_identity
        .get(&row.parent_tool_use_id)
        .cloned()
        .or_else(|| task_by_identity.get(&row.parent_uuid).cloned())
        .or_else(|| prompt_to_task.get(&row.prompt).cloned())
        .or_else(|| walk_chain_to_task(&row.parent_uuid, uuid_to_task, sidechain_by_uuid))
        .or_else(|| agent_to_task.get(&row.agent_id).cloned())
}

fn resolve_child(
    row: &SidechainRow,
    prompt_to_task: &HashMap<String, String>,
    uuid_to_task: &mut HashMap<String, String>,
    sidechain_by_uuid: &HashMap<String, &SidechainRow>,
    agent_to_task: &HashMap<String, String>,
) -> Option<String> {
    uuid_to_task
        .get(&row.parent_tool_use_id)
        .cloned()
        .or_else(|| {
            if row.parent_uuid.is_empty() {
                None
            } else if let Some(task_id) = uuid_to_task.get(&row.parent_uuid).cloned() {
                Some(task_id)
            } else {
                walk_chain_to_task(&row.parent_uuid, uuid_to_task, sidechain_by_uuid)
                    .or_else(|| prompt_to_task.get(&row.prompt).cloned())
            }
        })
        .or_else(|| prompt_to_task.get(&row.prompt).cloned())
        .or_else(|| agent_to_task.get(&row.agent_id).cloned())
}

/// Return an index-aligned parent assignment for top-level sidechain rows.
///
/// Rows already nested under a Task are input context only. A non-empty
/// result at index `i` means Dart may remove that top-level row and attach it
/// to the returned Task id. Orphans remain `None`, preserving the existing
/// inline-rendering and walk-back policy.
pub fn plan_grouping(rows: &[SidechainRow]) -> Vec<Option<String>> {
    let mut task_by_identity = HashMap::new();
    let mut prompt_to_task = HashMap::new();
    let mut uuid_to_task = HashMap::new();

    // Index every Task in the existing tree before resolving any new row.
    for row in rows {
        if !is_agent_container(row) {
            continue;
        }
        let task_id = row.id.as_str();
        add_overwrite(&mut task_by_identity, &row.id, task_id);
        add_overwrite(&mut uuid_to_task, &row.id, task_id);
        add_overwrite(&mut task_by_identity, &row.uuid, task_id);
        add_overwrite(&mut uuid_to_task, &row.uuid, task_id);
        add_overwrite(&mut task_by_identity, &row.tool_use_id, task_id);
        add_overwrite(&mut uuid_to_task, &row.tool_use_id, task_id);
        if !row.prompt.is_empty() {
            add_overwrite(&mut prompt_to_task, &row.prompt, task_id);
        }
        for root_uuid in &row.root_uuids {
            add_overwrite(&mut uuid_to_task, root_uuid, task_id);
        }
    }

    // Existing non-Task descendants seed the nearest Task's identity map.
    // put-if-absent preserves the more specific mapping when identities
    // overlap across nested subagent trees.
    for row in rows {
        if is_agent_container(row) || row.ancestor_task_id.is_empty() {
            continue;
        }
        let task_id = row.ancestor_task_id.as_str();
        add_if_absent(&mut uuid_to_task, &row.id, task_id);
        add_if_absent(&mut uuid_to_task, &row.uuid, task_id);
        add_if_absent(&mut uuid_to_task, &row.tool_use_id, task_id);
        add_if_absent(&mut uuid_to_task, &row.parent_uuid, task_id);
    }

    let mut sidechain_by_uuid = HashMap::new();
    for row in rows {
        if row.top_level
            && (row.is_sidechain || row.kind == "sidechain-root")
            && !row.uuid.is_empty()
        {
            sidechain_by_uuid.insert(row.uuid.clone(), row);
        }
    }

    // Recover the legacy agentId fallback from any already-resolved nested
    // row. This is intentionally a separate pass so input order cannot make
    // a later child miss an earlier task identity.
    let mut agent_to_task = HashMap::new();
    for row in rows {
        if row.agent_id.is_empty() {
            continue;
        }
        let task_id = uuid_to_task
            .get(&row.parent_tool_use_id)
            .cloned()
            .or_else(|| uuid_to_task.get(&row.parent_uuid).cloned());
        if let Some(task_id) = task_id {
            agent_to_task.entry(row.agent_id.clone()).or_insert(task_id);
        }
    }

    let mut assignments = vec![None; rows.len()];
    for (index, row) in rows.iter().enumerate() {
        if !row.top_level {
            continue;
        }

        let is_root = row.kind == "sidechain-root";
        let is_child = row.is_sidechain
            || row.kind == "sidechain-link"
            || row.is_task_event
            || !row.parent_tool_use_id.is_empty();
        if !is_root && !is_child {
            continue;
        }

        let task_id = if is_root {
            resolve_root(
                row,
                &task_by_identity,
                &prompt_to_task,
                &mut uuid_to_task,
                &sidechain_by_uuid,
                &agent_to_task,
            )
        } else {
            resolve_child(
                row,
                &prompt_to_task,
                &mut uuid_to_task,
                &sidechain_by_uuid,
                &agent_to_task,
            )
        };

        let Some(task_id) = task_id else { continue };
        if row.id.is_empty() || row.id == task_id {
            continue;
        }

        assignments[index] = Some(task_id.clone());
        add_overwrite(&mut uuid_to_task, &row.id, &task_id);
        add_overwrite(&mut uuid_to_task, &row.uuid, &task_id);
        add_overwrite(&mut uuid_to_task, &row.tool_use_id, &task_id);
    }

    assignments
}

#[cfg(test)]
mod tests {
    use super::*;

    fn task(id: &str, uuid: &str) -> SidechainRow {
        SidechainRow {
            id: id.into(),
            uuid: uuid.into(),
            parent_uuid: String::new(),
            parent_tool_use_id: String::new(),
            tool_use_id: String::new(),
            prompt: String::new(),
            agent_id: String::new(),
            kind: "tool-call".into(),
            name: "Task".into(),
            is_sidechain: false,
            is_task_event: false,
            top_level: true,
            ancestor_task_id: String::new(),
            root_uuids: Vec::new(),
        }
    }

    fn child(id: &str, uuid: &str, parent_uuid: &str) -> SidechainRow {
        SidechainRow {
            id: id.into(),
            uuid: uuid.into(),
            parent_uuid: parent_uuid.into(),
            parent_tool_use_id: String::new(),
            tool_use_id: String::new(),
            prompt: String::new(),
            agent_id: String::new(),
            kind: "text".into(),
            name: String::new(),
            is_sidechain: true,
            is_task_event: false,
            top_level: true,
            ancestor_task_id: String::new(),
            root_uuids: Vec::new(),
        }
    }

    #[test]
    fn assigns_direct_child_and_leaves_orphan_inline() {
        let rows = vec![task("t1", "task-uuid"), child("c1", "c-uuid", "task-uuid")];
        let orphan = child("orphan", "o-uuid", "missing");
        let assignments = plan_grouping(&[rows, vec![orphan]].concat());
        assert_eq!(assignments[1], Some("t1".into()));
        assert_eq!(assignments[2], None);
    }

    #[test]
    fn resolves_transitive_chain_independent_of_row_order() {
        let rows = vec![
            task("t1", "task-uuid"),
            child("c2", "c2-uuid", "c1-uuid"),
            child("c1", "c1-uuid", "task-uuid"),
        ];
        let assignments = plan_grouping(&rows);
        assert_eq!(assignments[1], Some("t1".into()));
        assert_eq!(assignments[2], Some("t1".into()));
    }

    #[test]
    fn nested_task_can_receive_a_new_top_level_child() {
        let mut nested = task("inner", "inner-uuid");
        nested.top_level = false;
        nested.ancestor_task_id = "outer".into();
        let outer = task("outer", "outer-uuid");
        let child = child("c1", "c-uuid", "inner-uuid");
        let assignments = plan_grouping(&[outer, nested, child]);
        assert_eq!(assignments[2], Some("inner".into()));
    }

    #[test]
    fn self_cycle_is_not_planned() {
        let mut row = child("t1", "task-uuid", "task-uuid");
        row.kind = "tool-call".into();
        row.name = "Task".into();
        let assignments = plan_grouping(&[row]);
        assert_eq!(assignments, vec![None]);
    }
}
