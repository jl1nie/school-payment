//! Request handlers for JSON-RPC operations.
//!
//! These handlers are used by both Tauri commands and Axum HTTP endpoints.

use std::sync::Arc;
use tokio::sync::Mutex;

use crate::json_rpc::{JsonRpcRequest, JsonRpcResponse};
use crate::lean_repl::{LeanRepl, LeanReplError};

/// Shared state for the application
pub struct AppState {
    pub lean_repl: Mutex<LeanRepl>,
}

impl AppState {
    pub fn new(lean_repl: LeanRepl) -> Self {
        Self {
            lean_repl: Mutex::new(lean_repl),
        }
    }
}

/// Send an RPC request to the Lean REPL
pub async fn send_rpc(
    state: Arc<AppState>,
    request: JsonRpcRequest,
) -> Result<JsonRpcResponse, LeanReplError> {
    let mut repl = state.lean_repl.lock().await;

    // Log for debugging
    if request.method == "getWeeklyRecommendations" {
        tracing::info!("=== Weekly Recommendations Request ===");
        if let Some(start_day) = request.params.get("startDay") {
            tracing::info!("startDay: {}", start_day);
        }
        if let Some(states) = request.params.get("states") {
            tracing::info!("states: {}", serde_json::to_string_pretty(states).unwrap_or_default());
        }
    }

    repl.send_request(&request)
}

/// Health check response
#[derive(Debug, Clone, serde::Serialize)]
pub struct HealthResponse {
    pub status: String,
    pub lean_repl: String,
}

/// Check the health of the application
pub async fn health_check(state: Arc<AppState>) -> HealthResponse {
    let mut repl = state.lean_repl.lock().await;

    HealthResponse {
        status: "ok".to_string(),
        lean_repl: if repl.is_running() {
            "running".to_string()
        } else {
            "stopped".to_string()
        },
    }
}

/// Restart the Lean REPL
pub async fn restart_repl(state: Arc<AppState>) -> Result<(), LeanReplError> {
    let mut repl = state.lean_repl.lock().await;
    repl.restart()
}

/// Send a ping request to verify REPL connectivity
pub async fn ping(state: Arc<AppState>) -> Result<JsonRpcResponse, LeanReplError> {
    let request = JsonRpcRequest {
        jsonrpc: "2.0".to_string(),
        method: "ping".to_string(),
        params: serde_json::json!({}),
        id: serde_json::json!(std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64),
    };

    send_rpc(state, request).await
}
