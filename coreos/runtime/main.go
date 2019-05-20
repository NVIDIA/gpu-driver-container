package main

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"os/exec"
	"syscall"

	"github.com/opencontainers/runtime-spec/specs-go"
)

func execRunc() {
	runcPath, err := exec.LookPath("runc")
	if err != nil {
		os.Exit(1)
	}

	err = syscall.Exec(runcPath, append([]string{runcPath}, os.Args[1:]...), os.Environ())
	if err != nil {
		os.Exit(1)
	}
}

func addNVIDIAHook(spec *specs.Spec) error {
	path, err := exec.LookPath("nvidia-container-runtime-hook")
	if err != nil {
		return err
	}
	args := []string{path}
	if spec.Hooks == nil {
		spec.Hooks = &specs.Hooks{}
	}
	spec.Hooks.Prestart = append(spec.Hooks.Prestart, specs.Hook{
		Path: path,
		Args: append(args, "prestart"),
	})

	return nil
}


func main() {
	index := 0
	create := false

	for i, param := range os.Args {
		if param == "--bundle" || param == "-b" {
			if len(os.Args) < i + 2 {
				os.Exit(1)
			}
			index = i + 1
		} else if param == "create" {
			create = true
		}
	}

	if !create {
		execRunc()
	}

	if index == 0 {
		os.Exit(1)
	}

	jsonFile, err := os.OpenFile(os.Args[index] + "/config.json", os.O_RDWR, 0644)
	if err != nil {
		os.Exit(1)
	}

	jsonContent, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		os.Exit(1)
	}

	var spec specs.Spec
	err = json.Unmarshal(jsonContent, &spec)
	if err != nil {
		os.Exit(1)
	}

	if err = addNVIDIAHook(&spec); err != nil {
		os.Exit(1)
	}

	jsonOutput, err := json.Marshal(spec)
	if err != nil {
		os.Exit(1)
	}

	_, err = jsonFile.WriteAt(jsonOutput, 0)
	if err != nil {
		os.Exit(1)
	}

	err = jsonFile.Close()
	if err != nil {
		os.Exit(1)
	}

	execRunc()
}
