package process

import (
	"fmt"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
)

// Config holds process manager configuration
type Config struct {
	MaxAttempts     int           
	RetryDelay      time.Duration 
	ProcessPatterns []string      
}

// DefaultConfig returns the default configuration
func DefaultConfig() *Config {
	return &Config{
		MaxAttempts: 3,
		RetryDelay:  2 * time.Second,
		ProcessPatterns: []string{
			"Cursor.exe",
			"Cursor ",    
			"cursor ",    
			"cursor",     
			"Cursor",     
			"*cursor*",   
			"*Cursor*",   
		},
	}
}

// Manager handles process-related operations
type Manager struct {
	config *Config
	log    *logrus.Logger
}

// NewManager creates a new process manager with optional config and logger
func NewManager(config *Config, log *logrus.Logger) *Manager {
	if config == nil {
		config = DefaultConfig()
	}
	if log == nil {
		log = logrus.New()
	}
	return &Manager{
		config: config,
		log:    log,
	}
}

// IsCursorRunning checks if any Cursor process is currently running
func (m *Manager) IsCursorRunning() bool {
	processes, err := m.getCursorProcesses()
	if err != nil {
		m.log.Warn("Failed to get Cursor processes:", err)
		return false
	}
	return len(processes) > 0
}

// KillCursorProcesses attempts to kill all running Cursor processes
func (m *Manager) KillCursorProcesses() error {
	for attempt := 1; attempt <= m.config.MaxAttempts; attempt++ {
		processes, err := m.getCursorProcesses()
		if err != nil {
			return fmt.Errorf("failed to get processes: %w", err)
		}

		if len(processes) == 0 {
			return nil
		}

		if runtime.GOOS == "windows" {
			for _, pid := range processes {
				exec.Command("taskkill", "/PID", pid).Run()
				time.Sleep(500 * time.Millisecond)
			}
		}

		remainingProcesses, _ := m.getCursorProcesses()
		for _, pid := range remainingProcesses {
			m.killProcess(pid)
		}

		time.Sleep(m.config.RetryDelay)

		if processes, _ := m.getCursorProcesses(); len(processes) == 0 {
			return nil
		}
	}
	return nil
}

// Process listing functions
func (m *Manager) getCursorProcesses() ([]string, error) {
	cmd := m.getProcessListCommand()
	if cmd == nil {
		return nil, fmt.Errorf("unsupported OS: %s", runtime.GOOS)
	}

	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to execute command: %w", err)
	}

	return m.parseProcessList(string(output)), nil
}

func (m *Manager) getProcessListCommand() *exec.Cmd {
	switch runtime.GOOS {
	case "windows":
		return exec.Command("tasklist", "/FO", "CSV", "/NH")
	case "darwin":
		return exec.Command("ps", "-ax")
	case "linux":
		return exec.Command("ps", "-A")
	default:
		return nil
	}
}

func (m *Manager) parseProcessList(output string) []string {
	var processes []string
	for _, line := range strings.Split(output, "\n") {
		lowerLine := strings.ToLower(line)
		if m.isOwnProcess(lowerLine) {
			continue
		}
		if pid := m.findCursorProcess(line, lowerLine); pid != "" {
			processes = append(processes, pid)
		}
	}
	return processes
}

// Process matching functions
func (m *Manager) isOwnProcess(line string) bool {
	return strings.Contains(line, "cursor-id-modifier") ||
		strings.Contains(line, "cursor-helper")
}

func (m *Manager) findCursorProcess(line, lowerLine string) string {
	for _, pattern := range m.config.ProcessPatterns {
		if m.matchPattern(lowerLine, strings.ToLower(pattern)) {
			return m.extractPID(line)
		}
	}
	return ""
}

func (m *Manager) matchPattern(line, pattern string) bool {
	switch {
	case strings.HasPrefix(pattern, "*") && strings.HasSuffix(pattern, "*"):
		search := pattern[1 : len(pattern)-1]
		return strings.Contains(line, search)
	case strings.HasPrefix(pattern, "*"):
		return strings.HasSuffix(line, pattern[1:])
	case strings.HasSuffix(pattern, "*"):
		return strings.HasPrefix(line, pattern[:len(pattern)-1])
	default:
		return line == pattern
	}
}

// Process killing functions
func (m *Manager) extractPID(line string) string {
	switch runtime.GOOS {
	case "windows":
		parts := strings.Split(line, ",")
		if len(parts) >= 2 {
			return strings.Trim(parts[1], "\"")
		}
	case "darwin", "linux":
		parts := strings.Fields(line)
		if len(parts) >= 1 {
			return parts[0]
		}
	}
	return ""
}

func (m *Manager) killProcess(pid string) error {
	cmd := m.getKillCommand(pid)
	if cmd == nil {
		return fmt.Errorf("unsupported OS: %s", runtime.GOOS)
	}
	return cmd.Run()
}

func (m *Manager) getKillCommand(pid string) *exec.Cmd {
	switch runtime.GOOS {
	case "windows":
		return exec.Command("taskkill", "/F", "/PID", pid)
	case "darwin", "linux":
		return exec.Command("kill", "-9", pid)
	default:
		return nil
	}
}
