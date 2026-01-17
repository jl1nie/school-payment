//! File storage for persisting application data.
//!
//! Used primarily by the Tauri desktop application to save/load school data.

use std::fs;
use std::path::PathBuf;

use thiserror::Error;

/// Errors that can occur during storage operations
#[derive(Debug, Error)]
pub enum StorageError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON serialization error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Failed to get app data directory")]
    NoDataDir,
}

/// File-based storage for application data
pub struct Storage {
    data_dir: PathBuf,
}

impl Storage {
    /// Create a new Storage with the given data directory
    pub fn new(data_dir: PathBuf) -> Self {
        Self { data_dir }
    }

    /// Get the path to a data file
    fn data_path(&self, filename: &str) -> PathBuf {
        self.data_dir.join(filename)
    }

    /// Ensure the data directory exists
    fn ensure_dir(&self) -> Result<(), StorageError> {
        fs::create_dir_all(&self.data_dir)?;
        Ok(())
    }

    /// Save data to a file
    pub fn save(&self, filename: &str, data: &serde_json::Value) -> Result<(), StorageError> {
        self.ensure_dir()?;
        let path = self.data_path(filename);
        let content = serde_json::to_string_pretty(data)?;
        fs::write(path, content)?;
        Ok(())
    }

    /// Load data from a file
    pub fn load(&self, filename: &str) -> Result<Option<serde_json::Value>, StorageError> {
        let path = self.data_path(filename);
        if !path.exists() {
            return Ok(None);
        }
        let content = fs::read_to_string(path)?;
        let data: serde_json::Value = serde_json::from_str(&content)?;
        Ok(Some(data))
    }

    /// Check if a file exists
    pub fn exists(&self, filename: &str) -> bool {
        self.data_path(filename).exists()
    }

    /// Delete a file
    pub fn delete(&self, filename: &str) -> Result<(), StorageError> {
        let path = self.data_path(filename);
        if path.exists() {
            fs::remove_file(path)?;
        }
        Ok(())
    }
}

/// Default data filename for school data
pub const SCHOOLS_DATA_FILE: &str = "data.json";

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_save_and_load() {
        let dir = tempdir().unwrap();
        let storage = Storage::new(dir.path().to_path_buf());

        let data = serde_json::json!({
            "schools": [
                {"id": 1, "name": "Test University"}
            ]
        });

        storage.save("test.json", &data).unwrap();
        let loaded = storage.load("test.json").unwrap();

        assert!(loaded.is_some());
        assert_eq!(loaded.unwrap(), data);
    }

    #[test]
    fn test_load_nonexistent() {
        let dir = tempdir().unwrap();
        let storage = Storage::new(dir.path().to_path_buf());

        let loaded = storage.load("nonexistent.json").unwrap();
        assert!(loaded.is_none());
    }

    #[test]
    fn test_exists() {
        let dir = tempdir().unwrap();
        let storage = Storage::new(dir.path().to_path_buf());

        assert!(!storage.exists("test.json"));

        storage.save("test.json", &serde_json::json!({})).unwrap();
        assert!(storage.exists("test.json"));
    }

    #[test]
    fn test_delete() {
        let dir = tempdir().unwrap();
        let storage = Storage::new(dir.path().to_path_buf());

        storage.save("test.json", &serde_json::json!({})).unwrap();
        assert!(storage.exists("test.json"));

        storage.delete("test.json").unwrap();
        assert!(!storage.exists("test.json"));
    }
}
