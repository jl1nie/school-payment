//! Tauri desktop application for school-payment advisor.

mod commands;

use std::path::PathBuf;
use std::sync::Arc;

use tauri::Manager;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use rust_backend::{handlers::AppState, LeanRepl};

/// Get the path to the advisor binary
fn get_advisor_path(#[allow(unused)] app: &tauri::AppHandle) -> PathBuf {
    #[cfg(debug_assertions)]
    {
        // Development: use the local build
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("lean-backend")
            .join(".lake")
            .join("build")
            .join("bin")
            .join("advisor")
    }

    #[cfg(not(debug_assertions))]
    {
        // Production: use bundled resource
        let advisor_name = if cfg!(windows) { "advisor.exe" } else { "advisor" };
        app.path()
            .resource_dir()
            .expect("Failed to get resource directory")
            .join(advisor_name)
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "school_payment=debug,rust_backend=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .setup(|app| {
            let advisor_path = get_advisor_path(app.handle());
            tracing::info!("Advisor binary path: {:?}", advisor_path);

            // Initialize Lean REPL
            let mut lean_repl = LeanRepl::new(advisor_path);

            match lean_repl.start() {
                Ok(()) => tracing::info!("Lean REPL started successfully"),
                Err(e) => {
                    tracing::warn!("Could not start Lean REPL immediately: {}", e);
                    tracing::info!("Will attempt to start on first request");
                }
            }

            // Create shared state
            let state = Arc::new(AppState::new(lean_repl));
            app.manage(state);

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::send_rpc,
            commands::health_check,
            commands::restart_repl,
            commands::save_data,
            commands::load_data,
        ])
        .run(tauri::generate_context!())
        .expect("Error while running Tauri application");
}
