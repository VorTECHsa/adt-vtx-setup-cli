package main

import (
	"log"
	"os"

	"github.com/VorTECHsa/vcli/internal/cmd"
)

func main() {
	err := cmd.RunCommand(os.Args)

	if (err != nil) {
		log.Fatal(err)
		os.Exit(1)
	} else {
		os.Exit(0)
	}
}