package setup

import (
	"os"

	"github.com/VorTECHsa/vcli/internal/util"
	"github.com/urfave/cli/v2"
)

func ensureWorkspaceDirExists(workspaceDir string) error {
	if util.DoesPathExist(workspaceDir) {
		return nil
	}

	err := os.MkdirAll(workspaceDir, os.ModePerm)

	return err
}

func Action(cCtx *cli.Context) error {
	workspaceDir := util.CreatePathFromHomeDir("workspace")
	dryRun := true

	err := ensureWorkspaceDirExists(workspaceDir)
	if err != nil {
		return err
	}

	err = CloneGitRepos(workspaceDir, dryRun)
	if err != nil {
		return err
	}

	err = SetupApps(dryRun)
	if err != nil {
		return err
	}

	err = EnsureAliasesAreAdded(dryRun)
	if err != nil {
		return err
	}

	return nil
}

func Command() *cli.Command {
	return &cli.Command{
		Name: "setup",
		Usage: "Sets up a local development machine",
		Action: Action,
	}
}
