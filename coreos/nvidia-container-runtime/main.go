package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"syscall"

	"github.com/opencontainers/runtime-spec/specs-go"
)

type config struct {
	bundleDirPath string
	cmd           string
}

func getConfig() (*config, error) {
	cfg := &config{}

	for i, param := range os.Args {
		if param == "--bundle" || param == "-b" {
			if len(os.Args) < i + 2 {
				return nil, fmt.Errorf("bundle option needs an argument")
			}
			cfg.bundleDirPath = os.Args[i + 1]
		} else if param == "create" {
			cfg.cmd = param
		}
	}

	return cfg, nil
}

func exitOnError(err error, msg string) {
	if err != nil {
		log.Fatalf("ERROR: %s: %s: %v\n", os.Args[0], msg, err)
	}
}

func execRunc() {
	runcPath, err := exec.LookPath("runc")
	exitOnError(err, "find runc path")

	err = syscall.Exec(runcPath, append([]string{runcPath}, os.Args[1:]...), os.Environ())
	exitOnError(err, "exec runc binary")
}

func addNVIDIAHook(spec *specs.Spec) error {
	path, err := exec.LookPath("nvidia-container-runtime-hook")
	if err != nil {
		path := "/usr/bin/nvidia-container-runtime-hook"
		_, err = os.Stat(path)
		if err != nil {
			return err
		}
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
	cfg, err := getConfig()
	exitOnError(err, "fail to get config")

	if cfg.cmd != "create" {
		execRunc()
		log.Fatalf("ERROR: %s: fail to execute runc binary\n", os.Args[0])
	}

	if cfg.bundleDirPath == "" {
		cfg.bundleDirPath, err = os.Getwd()
		exitOnError(err, "get working directory")
	}

	jsonFile, err := os.OpenFile(cfg.bundleDirPath + "/config.json", os.O_RDWR, 0644)
	exitOnError(err, "open OCI spec file")

	defer jsonFile.Close()

	jsonContent, err := ioutil.ReadAll(jsonFile)
	exitOnError(err, "read OCI spec file")

	var spec specs.Spec
	err = json.Unmarshal(jsonContent, &spec)
	exitOnError(err, "unmarshal OCI spec file")

	err = addNVIDIAHook(&spec)
	exitOnError(err, "inject NVIDIA hook")

	jsonOutput, err := json.Marshal(spec)
	exitOnError(err, "marchal OCI spec file")

	_, err = jsonFile.WriteAt(jsonOutput, 0)
	exitOnError(err, "write OCI spec file")

	execRunc()
}
