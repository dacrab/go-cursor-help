// Package main provides functionality for modifying Cursor application identifiers
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"runtime"
	"runtime/debug"
	"strings"

	"github.com/yuaotian/go-cursor-help/internal/config"
	"github.com/yuaotian/go-cursor-help/internal/lang"
	"github.com/yuaotian/go-cursor-help/internal/process"
	"github.com/yuaotian/go-cursor-help/internal/ui"
	"github.com/yuaotian/go-cursor-help/pkg/idgen"

	"github.com/sirupsen/logrus"
)

// Global variables for command line flags and logging
var (
	version     = "dev"
	setReadOnly = flag.Bool("r", false, "set storage.json to read-only mode")
	showVersion = flag.Bool("v", false, "show version information")
	log         = logrus.New()
)

// main is the entry point of the application
func main() {
	setupErrorRecovery()
	handleFlags()
	setupLogger()

	username := getCurrentUser()
	log.Debug("Running as user:", username)

	// Initialize core components
	display := ui.NewDisplay(nil)
	configManager := initConfigManager(username)
	generator := idgen.NewGenerator()
	processManager := process.NewManager(nil, log)

	// Check and handle privileges before proceeding
	if err := handlePrivileges(display); err != nil {
		return
	}

	setupDisplay(display)

	// Handle running Cursor processes
	if err := handleCursorProcesses(display, processManager); err != nil {
		return
	}

	// Read existing config and generate new IDs
	text := lang.GetText()
	oldConfig := readExistingConfig(display, configManager, text)
	newConfig := generateNewConfig(display, generator, oldConfig, text)

	// Save the new configuration
	if err := saveConfiguration(display, configManager, newConfig); err != nil {
		return
	}

	showCompletionMessages(display)

	// Skip waiting for user input in automated mode
	if os.Getenv("AUTOMATED_MODE") != "1" {
		waitExit()
	}
}

// setupErrorRecovery sets up panic recovery to prevent crashes
func setupErrorRecovery() {
	defer func() {
		if r := recover(); r != nil {
			log.Errorf("Panic recovered: %v\n", r)
			debug.PrintStack()
			waitExit()
		}
	}()
}

// handleFlags processes command line flags
func handleFlags() {
	flag.Parse()
	if *showVersion {
		fmt.Printf("Cursor ID Modifier v%s\n", version)
		os.Exit(0)
	}
}

// setupLogger configures the logging system
func setupLogger() {
	log.SetFormatter(&logrus.TextFormatter{
		FullTimestamp:          true,
		DisableLevelTruncation: true,
		PadLevelText:           true,
	})
	log.SetLevel(logrus.InfoLevel)
}

// getCurrentUser retrieves the current username, considering sudo if applicable
func getCurrentUser() string {
	if username := os.Getenv("SUDO_USER"); username != "" {
		return username
	}

	user, err := user.Current()
	if err != nil {
		log.Fatal(err)
	}
	return user.Username
}

// initConfigManager creates and initializes the configuration manager
func initConfigManager(username string) *config.Manager {
	configManager, err := config.NewManager(username)
	if err != nil {
		log.Fatal(err)
	}
	return configManager
}

// handlePrivileges checks and handles administrative privileges
func handlePrivileges(display *ui.Display) error {
	isAdmin, err := checkAdminPrivileges()
	if err != nil {
		log.Error(err)
		waitExit()
		return err
	}

	if !isAdmin {
		if runtime.GOOS == "windows" {
			return handleWindowsPrivileges(display)
		}
		display.ShowPrivilegeError(
			lang.GetText().PrivilegeError,
			lang.GetText().RunWithSudo,
			lang.GetText().SudoExample,
		)
		waitExit()
		return fmt.Errorf("insufficient privileges")
	}
	return nil
}

// handleWindowsPrivileges handles privilege elevation on Windows systems
func handleWindowsPrivileges(display *ui.Display) error {
	message := "\nRequesting administrator privileges..."
	if lang.GetCurrentLanguage() == lang.CN {
		message = "\n请求管理员权限..."
	}
	fmt.Println(message)

	if err := selfElevate(); err != nil {
		log.Error(err)
		display.ShowPrivilegeError(
			lang.GetText().PrivilegeError,
			lang.GetText().RunAsAdmin,
			lang.GetText().RunWithSudo,
			lang.GetText().SudoExample,
		)
		waitExit()
		return err
	}
	return nil
}

// setupDisplay initializes the user interface
func setupDisplay(display *ui.Display) {
	if err := display.ClearScreen(); err != nil {
		log.Warn("Failed to clear screen:", err)
	}
	display.ShowLogo()
	fmt.Println()
}

// handleCursorProcesses manages running Cursor processes
func handleCursorProcesses(display *ui.Display, processManager *process.Manager) error {
	if os.Getenv("AUTOMATED_MODE") == "1" {
		log.Debug("Running in automated mode, skipping Cursor process closing")
		return nil
	}

	display.ShowProgress("Closing Cursor...")
	log.Debug("Attempting to close Cursor processes")

	if err := processManager.KillCursorProcesses(); err != nil {
		log.Error("Failed to close Cursor:", err)
		display.StopProgress()
		display.ShowError("Failed to close Cursor. Please close it manually and try again.")
		waitExit()
		return err
	}

	if processManager.IsCursorRunning() {
		log.Error("Cursor processes still detected after closing")
		display.StopProgress()
		display.ShowError("Failed to close Cursor completely. Please close it manually and try again.")
		waitExit()
		return fmt.Errorf("cursor still running")
	}

	log.Debug("Successfully closed all Cursor processes")
	display.StopProgress()
	fmt.Println()
	return nil
}

// readExistingConfig attempts to read the existing configuration
func readExistingConfig(display *ui.Display, configManager *config.Manager, text lang.TextResource) *config.StorageConfig {
	display.ShowProgress(text.ReadingConfig)
	oldConfig, err := configManager.ReadConfig()
	if err != nil {
		log.Warn("Failed to read existing config:", err)
		oldConfig = nil
	}
	display.StopProgress()
	fmt.Println()
	return oldConfig
}

// generateNewConfig creates a new configuration with generated IDs
func generateNewConfig(display *ui.Display, generator *idgen.Generator, oldConfig *config.StorageConfig, text lang.TextResource) *config.StorageConfig {
	display.ShowProgress(text.GeneratingIds)
	newConfig := &config.StorageConfig{}

	if machineID, err := generator.GenerateMachineID(); err != nil {
		log.Fatal("Failed to generate machine ID:", err)
	} else {
		newConfig.TelemetryMachineId = machineID
	}

	if macMachineID, err := generator.GenerateMacMachineID(); err != nil {
		log.Fatal("Failed to generate MAC machine ID:", err)
	} else {
		newConfig.TelemetryMacMachineId = macMachineID
	}

	if deviceID, err := generator.GenerateDeviceID(); err != nil {
		log.Fatal("Failed to generate device ID:", err)
	} else {
		newConfig.TelemetryDevDeviceId = deviceID
	}

	// Preserve existing SQM ID if available, otherwise generate new one
	if oldConfig != nil && oldConfig.TelemetrySqmId != "" {
		newConfig.TelemetrySqmId = oldConfig.TelemetrySqmId
	} else if sqmID, err := generator.GenerateSQMID(); err != nil {
		log.Fatal("Failed to generate SQM ID:", err)
	} else {
		newConfig.TelemetrySqmId = sqmID
	}

	display.StopProgress()
	fmt.Println()
	return newConfig
}

// saveConfiguration persists the new configuration
func saveConfiguration(display *ui.Display, configManager *config.Manager, newConfig *config.StorageConfig) error {
	display.ShowProgress("Saving configuration...")
	if err := configManager.SaveConfig(newConfig, *setReadOnly); err != nil {
		log.Error(err)
		waitExit()
		return err
	}
	display.StopProgress()
	fmt.Println()
	return nil
}

// showCompletionMessages displays success messages to the user
func showCompletionMessages(display *ui.Display) {
	display.ShowSuccess(lang.GetText().SuccessMessage, lang.GetText().RestartMessage)
	fmt.Println()

	message := "Operation completed!"
	if lang.GetCurrentLanguage() == lang.CN {
		message = "操作完成！"
	}
	display.ShowInfo(message)
}

// waitExit waits for user input before exiting
func waitExit() {
	fmt.Print(lang.GetText().PressEnterToExit)
	os.Stdout.Sync()
	bufio.NewReader(os.Stdin).ReadString('\n')
}

// checkAdminPrivileges verifies if the current process has administrative privileges
func checkAdminPrivileges() (bool, error) {
	switch runtime.GOOS {
	case "windows":
		return exec.Command("net", "session").Run() == nil, nil

	case "darwin", "linux":
		currentUser, err := user.Current()
		if err != nil {
			return false, fmt.Errorf("failed to get current user: %w", err)
		}
		return currentUser.Uid == "0", nil

	default:
		return false, fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}

// selfElevate attempts to re-run the current process with elevated privileges
func selfElevate() error {
	os.Setenv("AUTOMATED_MODE", "1")

	switch runtime.GOOS {
	case "windows":
		exe, _ := os.Executable()
		cwd, _ := os.Getwd()
		args := strings.Join(os.Args[1:], " ")

		cmd := exec.Command("cmd", "/C", "start", "runas", exe, args)
		cmd.Dir = cwd
		return cmd.Run()

	case "darwin", "linux":
		exe, err := os.Executable()
		if err != nil {
			return err
		}

		cmd := exec.Command("sudo", append([]string{exe}, os.Args[1:]...)...)
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()

	default:
		return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}
