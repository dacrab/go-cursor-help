package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/yuaotian/go-cursor-help/internal/platform"
)

// StorageConfig represents the storage configuration
type StorageConfig struct {
	TelemetryMacMachineId string `json:"telemetry.macMachineId"`
	TelemetryMachineId    string `json:"telemetry.machineId"`
	TelemetryDevDeviceId  string `json:"telemetry.devDeviceId"`
	LastModified          string `json:"lastModified"`
	Version               string `json:"version"`
}

// Manager handles configuration operations
type Manager struct {
	configPath string
	mu         sync.RWMutex
}

// NewManager creates a new configuration manager
func NewManager(username string) (*Manager, error) {
	configDir, err := platform.GetConfigDir(username)
	if err != nil {
		return nil, fmt.Errorf("failed to get config directory: %w", err)
	}
	return &Manager{configPath: filepath.Join(configDir, "storage.json")}, nil
}

// ReadConfig reads the existing configuration
func (m *Manager) ReadConfig() (*StorageConfig, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	data, err := os.ReadFile(m.configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config StorageConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	return &config, nil
}

// SaveConfig saves the configuration
func (m *Manager) SaveConfig(config *StorageConfig, readOnly bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if err := os.MkdirAll(filepath.Dir(m.configPath), 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	configMap := map[string]interface{}{
		"telemetry.macMachineId": config.TelemetryMacMachineId,
		"telemetry.machineId":    config.TelemetryMachineId,
		"telemetry.devDeviceId":  config.TelemetryDevDeviceId,
		"lastModified":           time.Now().UTC().Format(time.RFC3339),
	}

	content, err := json.MarshalIndent(configMap, "", "    ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	fileMode := os.FileMode(0666)
	if readOnly {
		fileMode = 0444
	}

	if err := os.WriteFile(m.configPath, content, fileMode); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}
