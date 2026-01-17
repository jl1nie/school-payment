//! Rust backend library for school-payment application.
//!
//! This library provides common functionality for both Tauri desktop and Axum web server.

pub mod json_rpc;
pub mod lean_repl;
pub mod handlers;
pub mod storage;

pub use json_rpc::{JsonRpcRequest, JsonRpcResponse, JsonRpcError};
pub use lean_repl::LeanRepl;
pub use handlers::{send_rpc, health_check, restart_repl};
pub use storage::Storage;
