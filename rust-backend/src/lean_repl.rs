//! Lean REPL process management.
//!
//! Handles spawning, communication, and lifecycle of the Lean advisor REPL process.

use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::Duration;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

use thiserror::Error;

use crate::json_rpc::{JsonRpcRequest, JsonRpcResponse};

/// Errors that can occur when interacting with the Lean REPL
#[derive(Debug, Error)]
pub enum LeanReplError {
    #[error("Failed to start Lean REPL: {0}")]
    StartFailed(String),

    #[error("Lean REPL is not running")]
    NotRunning,

    #[error("Failed to send request to Lean REPL: {0}")]
    SendFailed(String),

    #[error("Failed to receive response from Lean REPL: {0}")]
    ReceiveFailed(String),

    #[error("Timeout waiting for Lean REPL response")]
    Timeout,

    #[error("Invalid JSON response: {0}")]
    InvalidJson(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

/// Manages a Lean REPL process
pub struct LeanRepl {
    process: Option<Child>,
    advisor_path: PathBuf,
    response_rx: Option<Receiver<String>>,
    stdin_tx: Option<Sender<String>>,
}

impl LeanRepl {
    /// Create a new LeanRepl with the given advisor binary path
    pub fn new(advisor_path: PathBuf) -> Self {
        Self {
            process: None,
            advisor_path,
            response_rx: None,
            stdin_tx: None,
        }
    }

    /// Check if the REPL process is running
    pub fn is_running(&mut self) -> bool {
        if let Some(ref mut process) = self.process {
            match process.try_wait() {
                Ok(None) => true, // Still running
                _ => {
                    self.cleanup();
                    false
                }
            }
        } else {
            false
        }
    }

    /// Start the Lean REPL process
    pub fn start(&mut self) -> Result<(), LeanReplError> {
        if self.is_running() {
            return Ok(());
        }

        tracing::info!("Starting Lean REPL: {:?}", self.advisor_path);

        let mut cmd = Command::new(&self.advisor_path);
        cmd.arg("--repl")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        // Hide console window on Windows
        #[cfg(windows)]
        {
            const CREATE_NO_WINDOW: u32 = 0x08000000;
            cmd.creation_flags(CREATE_NO_WINDOW);
        }

        let mut process = cmd
            .spawn()
            .map_err(|e| LeanReplError::StartFailed(e.to_string()))?;

        // Set up stdin writer thread
        let stdin = process.stdin.take().ok_or_else(|| {
            LeanReplError::StartFailed("Failed to capture stdin".to_string())
        })?;
        let (stdin_tx, stdin_rx): (Sender<String>, Receiver<String>) = mpsc::channel();

        thread::spawn(move || {
            let mut stdin = stdin;
            while let Ok(msg) = stdin_rx.recv() {
                if stdin.write_all(msg.as_bytes()).is_err() {
                    break;
                }
                if stdin.flush().is_err() {
                    break;
                }
            }
        });

        // Set up stdout reader thread
        let stdout = process.stdout.take().ok_or_else(|| {
            LeanReplError::StartFailed("Failed to capture stdout".to_string())
        })?;
        let (response_tx, response_rx): (Sender<String>, Receiver<String>) = mpsc::channel();

        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            let mut buffer = String::new();

            for line in reader.lines() {
                match line {
                    Ok(line) => {
                        buffer.push_str(&line);
                        buffer.push('\n');

                        // Try to extract complete JSON objects
                        while let Some(json_str) = extract_json(&mut buffer) {
                            if response_tx.send(json_str).is_err() {
                                return;
                            }
                        }
                    }
                    Err(_) => break,
                }
            }
        });

        // Set up stderr reader thread (for logging)
        let stderr = process.stderr.take();
        if let Some(stderr) = stderr {
            thread::spawn(move || {
                let reader = BufReader::new(stderr);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        tracing::debug!("Lean REPL stderr: {}", line);
                    }
                }
            });
        }

        self.process = Some(process);
        self.response_rx = Some(response_rx);
        self.stdin_tx = Some(stdin_tx);

        // Wait a bit for the REPL to initialize
        thread::sleep(Duration::from_millis(500));

        // Drain any initial ready message
        if let Some(ref rx) = self.response_rx {
            while rx.try_recv().is_ok() {}
        }

        tracing::info!("Lean REPL started successfully");
        Ok(())
    }

    /// Send a request to the Lean REPL and wait for a response
    pub fn send_request(&mut self, request: &JsonRpcRequest) -> Result<JsonRpcResponse, LeanReplError> {
        if !self.is_running() {
            self.start()?;
        }

        let stdin_tx = self.stdin_tx.as_ref().ok_or(LeanReplError::NotRunning)?;
        let response_rx = self.response_rx.as_ref().ok_or(LeanReplError::NotRunning)?;

        // Serialize and send request
        let request_str = serde_json::to_string(request)
            .map_err(|e| LeanReplError::SendFailed(e.to_string()))?;

        tracing::debug!("Sending to Lean REPL: {}", request_str);

        stdin_tx
            .send(format!("{}\n", request_str))
            .map_err(|e| LeanReplError::SendFailed(e.to_string()))?;

        // Wait for response with timeout
        let timeout = Duration::from_secs(30);
        let response_str = response_rx
            .recv_timeout(timeout)
            .map_err(|e| match e {
                mpsc::RecvTimeoutError::Timeout => LeanReplError::Timeout,
                mpsc::RecvTimeoutError::Disconnected => {
                    LeanReplError::ReceiveFailed("REPL disconnected".to_string())
                }
            })?;

        tracing::debug!("Received from Lean REPL: {}", response_str);

        // Parse response
        let response: JsonRpcResponse = serde_json::from_str(&response_str)
            .map_err(|e| LeanReplError::InvalidJson(e.to_string()))?;

        Ok(response)
    }

    /// Restart the Lean REPL process
    pub fn restart(&mut self) -> Result<(), LeanReplError> {
        self.stop();
        self.start()
    }

    /// Stop the Lean REPL process
    pub fn stop(&mut self) {
        if let Some(mut process) = self.process.take() {
            let _ = process.kill();
            let _ = process.wait();
        }
        self.cleanup();
    }

    fn cleanup(&mut self) {
        self.process = None;
        self.response_rx = None;
        self.stdin_tx = None;
    }
}

impl Drop for LeanRepl {
    fn drop(&mut self) {
        self.stop();
    }
}

/// Extract a complete JSON object from the buffer
fn extract_json(buffer: &mut String) -> Option<String> {
    let start_idx = buffer.find('{')?;

    let mut depth = 0;
    let mut in_string = false;
    let mut escape = false;
    let mut end_idx = None;

    for (i, c) in buffer[start_idx..].char_indices() {
        if escape {
            escape = false;
            continue;
        }
        if c == '\\' {
            escape = true;
            continue;
        }
        if c == '"' {
            in_string = !in_string;
            continue;
        }
        if in_string {
            continue;
        }
        if c == '{' {
            depth += 1;
        } else if c == '}' {
            depth -= 1;
            if depth == 0 {
                end_idx = Some(start_idx + i);
                break;
            }
        }
    }

    let end_idx = end_idx?;
    let json_str = buffer[start_idx..=end_idx].to_string();
    *buffer = buffer[end_idx + 1..].to_string();

    // Validate it's valid JSON and skip ready messages (id: 0)
    if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&json_str) {
        if parsed.get("id") == Some(&serde_json::json!(0)) {
            // Skip ready message, try to find another JSON
            return extract_json(buffer);
        }
        Some(json_str)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_json_simple() {
        let mut buffer = r#"{"jsonrpc":"2.0","result":{},"id":1}"#.to_string();
        let json = extract_json(&mut buffer);
        assert!(json.is_some());
        assert!(buffer.is_empty());
    }

    #[test]
    fn test_extract_json_with_nested() {
        let mut buffer = r#"{"result":{"action":{"type":"doNothing"}},"id":1}"#.to_string();
        let json = extract_json(&mut buffer);
        assert!(json.is_some());
        assert!(buffer.is_empty());
    }

    #[test]
    fn test_extract_json_with_trailing() {
        let mut buffer = r#"{"id":1}extra"#.to_string();
        let json = extract_json(&mut buffer);
        assert!(json.is_some());
        assert_eq!(buffer, "extra");
    }

    #[test]
    fn test_extract_json_incomplete() {
        let mut buffer = r#"{"id":1"#.to_string();
        let json = extract_json(&mut buffer);
        assert!(json.is_none());
    }
}
