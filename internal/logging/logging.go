package logging

import (
	"fmt"
)

func LogStepHeader(msg string) {
	fmt.Println("\n==> " + msg)
}

func LogStep(msg string) {
	fmt.Println("--> " + msg)
}

func LogSuccess(msg string) {
	fmt.Println(":)  " + msg)
}

func LogInfo(msg string) {
	fmt.Println("i   " + msg)
}
