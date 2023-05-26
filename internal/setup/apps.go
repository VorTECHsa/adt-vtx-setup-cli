package setup

import (
	"fmt"
	"log"
	"os/exec"
	"os/user"
	"path"
	"strings"

	"github.com/VorTECHsa/vcli/internal/logging"
	"github.com/VorTECHsa/vcli/internal/util"
)

// From https://brew.sh/
var HOMEBREW_INSTALL_CMD = []string{ "/bin/bash",  "-c", "\"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" }

// From https://www.notion.so/vortexa/Dev-setup-5947d72171b14a62bfe6155524554953?pvs=4#92fbec17df314aafb289cd38cf3e8d98
var HOMEBREW_APPS = []string{
	"insomnia",
	"visual-studio-code",
	"obs",
	"stats",
	"sops",
}

// TODO: This is workaround-ish. Should improve how homebrew apps are declared.
var CASKLESS_HOMEBREW_APPS = []string{"sops"}

// From https://github.com/nvm-sh/nvm
var NVM_INSTALL_CMD = []string{ "curl", "-o-", "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash" }

func installNvm(dryRun bool) error {
	logging.LogStep("Installing NVM")
	if dryRun {
		fmt.Println("[dry-run] " + strings.Join(NVM_INSTALL_CMD, " "))
		return nil
	} else {
		cmd := exec.Command(NVM_INSTALL_CMD[0], NVM_INSTALL_CMD[1:]...)
		output, err := cmd.Output()
		util.LogCmdOutput(output)
		return err
	}
}

func installHomebrew(dryRun bool) error {
	logging.LogStep("Installing Homebrew")
	if dryRun {
		fmt.Println("[dry-run] " + strings.Join(HOMEBREW_INSTALL_CMD, " "))
		return nil
	} else {
		cmd := exec.Command(HOMEBREW_INSTALL_CMD[0], HOMEBREW_INSTALL_CMD[1:]...)
		output, err := cmd.Output()
		util.LogCmdOutput(output)
		return err
	}
}

func isAppCaskless(appName string) bool {
	for _, v := range CASKLESS_HOMEBREW_APPS {
			if appName == v {
					return true
			}
	}
	return false
}

func installHomebrewApp(appName string, dryRun bool) error {
	logging.LogStep(appName)
	cmdArgs := []string{ "brew", "install" }
	if !isAppCaskless(appName) {
		cmdArgs = append(cmdArgs, "--cask")
	}

	cmdArgs = append(cmdArgs, appName)
	if dryRun {
		fmt.Println("[dry-run] " + strings.Join(cmdArgs, " "))
		return nil
	} else {
		cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
		output, err := cmd.Output()
		util.LogCmdOutput(output)
		return err
	}
}

func installHomebrewApps(dryRun bool) error {
	logging.LogStep("Installing apps via Homebrew")

	for _, app := range HOMEBREW_APPS {
		err := installHomebrewApp(app, dryRun)
		if err != nil {
			return err
		}
	}

	return nil
}

func ensureHomebrewInstalled(dryRun bool) error {
	logging.LogStep("Checking if homebrew is installed")
	if !util.IsCommandAvailable("brew") {
		logging.LogInfo("Homebrew not installed")
		err := installHomebrew(dryRun)
		if err != nil {
			return err
		}
		logging.LogSuccess("Homebrew installed")
	} else {
		logging.LogInfo("Homebrew already installed; skipping.")
	}

	return nil
}

func isNvmInstalled() bool {
	const TOKEN = "export NVM_DIR=\"$HOME/.nvm\""

	user, err := user.Current()
	if (err != nil) {
		logging.LogInfo("An error occurred whilst trying to get the current OS user.")
		log.Fatal(err)
	}

	exists, err := util.DoesFileContainStringByPath(path.Join(user.HomeDir, ".zshrc"), TOKEN)
	if (err != nil) {
		log.Fatal(err)
	}

	return exists
}

func ensureNvmInstalled(dryRun bool) error {
	logging.LogStep("Checking if NVM is installed")
	if !isNvmInstalled() {
		logging.LogInfo("NVM not installed")
		err := installNvm(dryRun)
		if err != nil {
			return err
		}
		logging.LogSuccess("NVM installed")
	} else {
		logging.LogInfo("NVM already installed; skipping.")
	}

	return nil
}

func SetupApps(dryRun bool) error {
	logging.LogStepHeader("Installing apps")

	err := ensureHomebrewInstalled(dryRun)
	if (err != nil) {
		return err
	}

	err = installHomebrewApps(dryRun)
	if (err != nil) {
		return err
	}

	err = ensureNvmInstalled(dryRun)
	if (err != nil) {
		return err
	}

	return nil
}
