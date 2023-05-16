package setup

import (
	"fmt"

	"github.com/VorTECHsa/vcli/internal/constants"
	"github.com/VorTECHsa/vcli/internal/logging"
	"github.com/VorTECHsa/vcli/internal/util"
)

var token = fmt.Sprintf("# -- Aliases (added by %s)", constants.NAME)

var text = `

# General Conveniences
alias c='clear'
alias cls='clear'

# Git
alias gs='git status'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gc='git commit'
alias gcm='git commit -m'
alias gm='git merge'
alias gp='git push'
alias gf='git fetch'
alias gp='git push'
alias gl='git pull'`

func EnsureAliasesAreAdded(dryRun bool) error {
	filePath := util.CreatePathFromHomeDir(".zprofile")
	logging.LogStepHeader(fmt.Sprintf("Ensuring aliases are added to %s", filePath))
	return util.EnsureFileExistsAndHasText(filePath, text, token, dryRun)
}
