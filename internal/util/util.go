package util

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"strings"

	"github.com/VorTECHsa/vcli/internal/logging"
)

func ExecCmd(dry bool, name string, args ...string) {

}

func DoesPathExist(path string) bool {
	_, err := os.Stat(path)
	return !os.IsNotExist(err)
}

func IsCommandAvailable(name string) bool {
	isAvailViaLookPath := IsCommandAvailableViaLookPath(name)
	if isAvailViaLookPath {
		return true
	}

	return IsCommandAvailableViaWhich(name)
}

func IsCommandAvailableViaLookPath(name string) bool {
	path, err := exec.LookPath(name)
	logging.LogInfo("(" + path + ")")
	return err == nil
}

func IsCommandAvailableViaWhich(name string) bool {
	cmd := exec.Command("command", "-v", name)
	output, err := cmd.Output()
	if output != nil {
		logging.LogInfo("(" + strings.TrimSpace(string(output)) + ")")
	}
	return err == nil
}

func DoesFileContainStringByPath(filePath string, s string) (bool, error) {
	file, err := os.Open(filePath)
	if (err != nil) {
		logging.LogInfo(fmt.Sprintf("An error occurred whilst trying to read %s", filePath))
		return false, err
	}

	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if strings.Contains(scanner.Text(), s) {
			return true, nil
		}
	}

	return false, nil
}

func DoesFileContainString(file *os.File, s string) bool {
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if strings.Contains(scanner.Text(), s) {
			return true
		}
	}

	return false
}

func CreatePathFromHomeDir(relPath string) string {
	homeDir, err := os.UserHomeDir()
	if (err != nil) {
		logging.LogInfo("An error occurred whilst trying to get the current OS user.")
		log.Fatal(err)
	}

	return path.Join(homeDir, relPath)
}

func GetOrCreateFile(filePath string, dryRun bool) (*os.File, error) {
	if !DoesPathExist(filePath) {
		if dryRun {
			logging.LogStep(fmt.Sprintf("[dry-run] Creating file \"%s\"", filePath))
			return nil, nil
		} else {
			file, err := os.Create(filePath)
			return file, err
		}
	}

	return os.OpenFile(filePath, os.O_APPEND|os.O_WRONLY, 0644)
}

func EnsureFileExistsAndHasText(filePath string, text string, token string, dryRun bool) error {
	logging.LogStep(fmt.Sprintf("Ensuring that file exists: \"%s\"", filePath))
	file, err := GetOrCreateFile(filePath, dryRun)
	if (err != nil) {
		return err
	}

	logging.LogStep(fmt.Sprintf("Checking if file contains token: \"%s\"", token))
	exists, _ := DoesFileContainStringByPath(filePath, token)
	if exists {
		logging.LogStep("File already contains token; skipping.")
		return nil
	}

	logging.LogStep("Adding text to file")
	textToWrite := fmt.Sprintf(`%s\n\n%s`, token, text)
	_, err = file.WriteString(textToWrite)
	return err
}

func LogCmdOutput(bytes []byte) {
	text := strings.TrimSpace(string(bytes))
	if len(text) == 0 {
		return
	}

	logging.LogInfo(text)
}
