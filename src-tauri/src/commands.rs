//! Tauri commands that expose rust-backend functionality to the frontend.

use std::sync::Arc;

use tauri::{AppHandle, Manager, State};

use rust_backend::{
    handlers::{self, AppState, HealthResponse},
    json_rpc::{JsonRpcRequest, JsonRpcResponse},
    storage::{Storage, SCHOOLS_DATA_FILE},
};

/// Send an RPC request to the Lean REPL
#[tauri::command]
pub async fn send_rpc(
    state: State<'_, Arc<AppState>>,
    request: JsonRpcRequest,
) -> Result<JsonRpcResponse, String> {
    handlers::send_rpc(state.inner().clone(), request)
        .await
        .map_err(|e| e.to_string())
}

/// Check the health of the application
#[tauri::command]
pub async fn health_check(state: State<'_, Arc<AppState>>) -> Result<HealthResponse, String> {
    Ok(handlers::health_check(state.inner().clone()).await)
}

/// Restart the Lean REPL
#[tauri::command]
pub async fn restart_repl(state: State<'_, Arc<AppState>>) -> Result<(), String> {
    handlers::restart_repl(state.inner().clone())
        .await
        .map_err(|e| e.to_string())
}

/// Save data to local storage
#[tauri::command]
pub async fn save_data(app: AppHandle, data: serde_json::Value) -> Result<(), String> {
    let data_dir = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?;

    let storage = Storage::new(data_dir);
    storage
        .save(SCHOOLS_DATA_FILE, &data)
        .map_err(|e| e.to_string())
}

/// Load data from local storage
#[tauri::command]
pub async fn load_data(app: AppHandle) -> Result<Option<serde_json::Value>, String> {
    let data_dir = app
        .path()
        .app_data_dir()
        .map_err(|e| e.to_string())?;

    let storage = Storage::new(data_dir);
    storage.load(SCHOOLS_DATA_FILE).map_err(|e| e.to_string())
}
