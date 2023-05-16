package setup

import (
	"fmt"
	"os"
	"os/exec"
	"path"
	"strings"

	"github.com/VorTECHsa/vcli/internal/logging"
	"github.com/VorTECHsa/vcli/internal/util"
)

const (
	GITHUB_REPOS_SSH_PREFIX = "git@github.com:VorTECHsa/"
)

var REPO_GROUPS = map[string][]string{
	// From https://www.notion.so/vortexa/Dev-setup-5947d72171b14a62bfe6155524554953?pvs=4#d925cdb4509e445eaedfcaa8a816d512
	"adt": { "web", "app-core", "api" },
}

func cloneGitRepo(name string, dir string, dryRun bool) error {
	repoDirPath := path.Join(dir, name)
	repoDirExists := util.DoesPathExist(repoDirPath)
	if repoDirExists {
		logging.LogInfo(fmt.Sprintf("'%s' directory already exists; skipping.", repoDirPath))
		return nil
	}
	repoRemote := GITHUB_REPOS_SSH_PREFIX + name + ".git"
	cmdArgs := []string{ "git", "clone", repoRemote }

	if dryRun {
		fmt.Println("[dry-run] " + strings.Join(cmdArgs, " "))
		return nil
	} else {
		if !util.DoesPathExist(dir) {
			os.MkdirAll(dir, os.ModePerm)
		}
		cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
		cmd.Dir = dir
		output, err := cmd.Output()
		util.LogCmdOutput(output)
		return err
	}
}

func CloneGitRepos(workspaceDir string, dryRun bool) error {
	logging.LogStepHeader("Cloning repositories")

	for repoGroupName, repos := range REPO_GROUPS {
		for _, repoName := range repos {
			repoParentDir := path.Join(workspaceDir, repoGroupName)
			logging.LogStep("(" + repoGroupName + ") " + repoName + " --> " + path.Join(repoParentDir, repoName))
			err := cloneGitRepo(repoName, repoParentDir, dryRun)
			if err != nil {
				return err
			}
		}
	}

	return nil
}
