package cmd

import (
	"github.com/VorTECHsa/vcli/internal/constants"
	"github.com/VorTECHsa/vcli/internal/setup"
	"github.com/urfave/cli/v2"
)

func RunCommand(args []string) error {
	return (&cli.App{
		Name:  constants.NAME,
		Usage: constants.DESCRIPTION,
		Commands: []*cli.Command{
			setup.Command(),
		},
	}).Run(args)
}
