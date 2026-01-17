//! Axum HTTP server for the school-payment web application.
//!
//! This server wraps the rust-backend library and exposes HTTP endpoints.

use std::env;
use std::path::PathBuf;
use std::sync::Arc;

use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use tower_http::cors::{Any, CorsLayer};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use rust_backend::{
    handlers::{self, AppState, HealthResponse},
    json_rpc::{JsonRpcRequest, JsonRpcResponse},
    LeanRepl,
};

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "web_server=debug,rust_backend=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Get configuration from environment
    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(3001);

    let lean_backend_path = env::var("LEAN_BACKEND_PATH")
        .unwrap_or_else(|_| "../lean-backend".to_string());

    let advisor_path = PathBuf::from(&lean_backend_path)
        .join(".lake")
        .join("build")
        .join("bin")
        .join("advisor");

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

    // Configure CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Build router
    let app = Router::new()
        .route("/rpc", post(rpc_handler))
        .route("/health", get(health_handler))
        .route("/ping", get(ping_handler))
        .layer(cors)
        .with_state(state);

    // Start server
    let addr = format!("0.0.0.0:{}", port);
    tracing::info!("API Server running on http://{}", addr);
    tracing::info!("  - POST /rpc - JSON-RPC endpoint");
    tracing::info!("  - GET /health - Health check");
    tracing::info!("  - GET /ping - Test Lean REPL connection");

    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}

/// Handle JSON-RPC requests
async fn rpc_handler(
    State(state): State<Arc<AppState>>,
    Json(request): Json<JsonRpcRequest>,
) -> impl IntoResponse {
    match handlers::send_rpc(state, request.clone()).await {
        Ok(response) => (StatusCode::OK, Json(response)),
        Err(e) => {
            tracing::error!("RPC error: {}", e);
            let response = JsonRpcResponse::internal_error(request.id, e.to_string());
            (StatusCode::INTERNAL_SERVER_ERROR, Json(response))
        }
    }
}

/// Handle health check requests
async fn health_handler(State(state): State<Arc<AppState>>) -> Json<HealthResponse> {
    Json(handlers::health_check(state).await)
}

/// Handle ping requests
async fn ping_handler(
    State(state): State<Arc<AppState>>,
) -> Result<Json<JsonRpcResponse>, (StatusCode, String)> {
    match handlers::ping(state).await {
        Ok(response) => Ok(Json(response)),
        Err(e) => Err((StatusCode::INTERNAL_SERVER_ERROR, e.to_string())),
    }
}

/// Graceful shutdown signal handler
async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("Failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    tracing::info!("Shutting down...");
}
