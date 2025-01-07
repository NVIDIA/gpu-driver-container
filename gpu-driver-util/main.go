package main

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"path"
	"slices"
	"strings"

	log "github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
)

const (
	// LogFile is the path for logging
	LogFile = "/var/log/gpu-driver-util.log"
	// PCIDevicesRoot represents base path for all pci devices under sysfs
	PCIDevicesRoot = "/sys/bus/pci/devices"
	// NVIDIAVendorID represents the NVIDIA PCI vendor id
	NVIDIAVendorID = "0x10de"
	// PCIDeviceClassVGA represents the pci device class code for VGA devices
	PCIDeviceClassVGA = "0x030000"
	// PCIDeviceClassGPU represents the pci device class code for GPU devices
	PCIDeviceClassGPU = "0x030200"

	// DriverHintUnknown is used when the gpu device is not found in supported-gpus.json
	DriverHintUnknown = "unknown"
	// DriverHintOpenRequired is used when the gpu device compulsorily needs the OpenRM kernel modules
	DriverHintOpenRequired = "open-required"
	// DriverHintProprietaryRequired is used when the gpu device compulsorily needs the proprietary kernel modules
	DriverHintProprietaryRequired = "proprietary-required"
	// DriverHintAny is used when the gpu device can support either kernel module types
	DriverHintAny = "any-supported"

	// DriverFeatureKernelOpen indicates that the gpu device supports OpenRM
	DriverFeatureKernelOpen = "kernelopen"
	// DriverFeatureKernelGSPProprietary indicates that the gpu device has GSP RM and supports proprietary modules
	DriverFeatureKernelGSPProprietary = "gsp_proprietary_supported"

	// KernelModuleTypeOpen indicates the OpenRM Kernel Modules of the NVIDIA CUDA driver
	KernelModuleTypeOpen = "kernel-open"
	// KernelModuleTypeProprietary indicates the Closed/Proprietary Kernel Modules of the NVIDIA CUDA driver
	KernelModuleTypeProprietary = "kernel"
)

var (
	supportedGpusJsonPath string
	driverBranch          int
)

//go:embed supported-gpus.json
var defaultSupportedGpusJson string

type GPUDevice struct {
	ID           string   `json:"devid"`
	Name         string   `json:"name"`
	LegacyBranch string   `json:"legacybranch"`
	Features     []string `json:"features"`
}

type GPUData struct {
	Chips []GPUDevice `json:"chips"`
}

func main() {
	logFile, err := initializeLogger()
	if err != nil {
		log.Fatal(err.Error())
	}
	defer logFile.Close()

	// Create the top-level CLI app
	c := cli.NewApp()
	c.Name = "gpu-driver-util"
	c.Usage = "NVIDIA GPU Driver Utility Application"
	c.Version = "0.1.0"

	getKernelModule := cli.Command{}
	getKernelModule.Name = "get-kernel-module-type"
	getKernelModule.Usage = "Automatically determine the kernel module type based on the GPUs detected."
	getKernelModule.Action = func(c *cli.Context) error {
		return GetKernelModule(c)
	}

	getKernelModuleFlags := []cli.Flag{
		&cli.StringFlag{
			Name:        "supported-gpus-file",
			Aliases:     []string{"f"},
			Usage:       "Specify location of the supported-gpus.json file",
			Destination: &supportedGpusJsonPath,
			Required:    false,
		},
		&cli.IntFlag{
			Name:        "driver-branch",
			Aliases:     []string{"b"},
			Usage:       "Specify driver branch",
			EnvVars:     []string{"DRIVER_BRANCH"},
			Destination: &driverBranch,
			Required:    true,
		},
	}

	c.Commands = []*cli.Command{
		&getKernelModule,
	}

	getKernelModule.Flags = append([]cli.Flag{}, getKernelModuleFlags...)

	// Run the top-level CLI
	if err := c.Run(os.Args); err != nil {
		log.Fatal(fmt.Errorf("error running gpu-driver-util: %w", err))
	}

}

func initializeLogger() (*os.File, error) {
	logFile, err := os.OpenFile(LogFile, os.O_APPEND|os.O_CREATE|os.O_RDWR, 0666)
	if err != nil {
		return nil, fmt.Errorf("error opening file %s: %w", LogFile, err)
	}
	// Log as JSON instead of the default ASCII formatter.
	log.SetFormatter(&log.JSONFormatter{})
	// Output to file instead of stdout
	log.SetOutput(logFile)

	// Only log the warning severity or above.
	log.SetLevel(log.DebugLevel)
	return logFile, nil
}

func GetKernelModule(c *cli.Context) error {
	log.Infof("Starting the 'get-kernel-module' command of %s", c.App.Name)
	gpuDevices, err := getNvidiaGPUs()

	log.Debugf("NVIDIA GPU devices found: %v", gpuDevices)

	if err != nil {
		return err
	}

	var jsonData []byte
	if len(supportedGpusJsonPath) > 0 {
		jsonData, err = os.ReadFile(supportedGpusJsonPath)
		if err != nil {
			return fmt.Errorf("error opening the supported gpus file %s: %w", supportedGpusJsonPath, err)
		}
	} else {
		jsonData = []byte(defaultSupportedGpusJson)
	}

	var gpuData GPUData
	err = json.Unmarshal(jsonData, &gpuData)
	if err != nil {
		return fmt.Errorf("error unmarshaling the supported gpus json %s: %w", supportedGpusJsonPath, err)
	}

	searchMap := buildGPUSearchMap(gpuData)

	if len(gpuDevices) > 0 {
		kernelModuleType, err := resolveKernelModuleType(gpuDevices, searchMap)
		if err != nil {
			return fmt.Errorf("error resolving kernel module type: %w", err)
		}
		fmt.Println(kernelModuleType)
	}
	return nil
}

func resolveKernelModuleType(gpuDevices []string, searchMap map[string]GPUDevice) (string, error) {
	var kernelModuleType string
	driverHints := getDriverHints(gpuDevices, searchMap)
	log.Debugf("driverHints: %v", driverHints)

	// NOTE: driver hint "unknown" is assigned to a device that does not have an entry in supported-gpus.json.
	// In these cases, we assume that the gpu device is new and unreleased, and we default to OpenRM
	requiresOpenRM := slices.Contains(driverHints, DriverHintOpenRequired) || slices.Contains(driverHints, DriverHintUnknown)
	requiresProprietary := slices.Contains(driverHints, DriverHintProprietaryRequired)

	if requiresOpenRM && requiresProprietary {
		return "", fmt.Errorf("unsupported GPU topology")
	} else if requiresOpenRM {
		kernelModuleType = KernelModuleTypeOpen
	} else if requiresProprietary {
		kernelModuleType = KernelModuleTypeProprietary
	} else {
		kernelModuleType = getDriverBranchDefault(driverBranch)
	}
	log.Debugf("printing the recommended kernel module type: %s", kernelModuleType)
	return kernelModuleType, nil
}

func getDriverHints(gpuDevices []string, searchMap map[string]GPUDevice) []string {
	var driverHints []string

	for _, gpuDevice := range gpuDevices {
		if val, ok := searchMap[gpuDevice]; ok {
			gpuFeatures := val.Features
			if slices.Contains(gpuFeatures, DriverFeatureKernelGSPProprietary) &&
				slices.Contains(gpuFeatures, DriverFeatureKernelOpen) {
				driverHints = append(driverHints, DriverHintAny)
			} else if slices.Contains(gpuFeatures, DriverFeatureKernelOpen) {
				driverHints = append(driverHints, DriverHintOpenRequired)
			} else {
				driverHints = append(driverHints, DriverHintProprietaryRequired)
			}
		} else {
			driverHints = append(driverHints, DriverHintUnknown)
		}
	}
	return driverHints
}

func getDriverBranchDefault(driverBranch int) string {
	if driverBranch >= 560 {
		return KernelModuleTypeOpen
	}
	return KernelModuleTypeProprietary
}

func buildGPUSearchMap(data GPUData) map[string]GPUDevice {
	var gpuMap = make(map[string]GPUDevice)
	for _, gpuDevice := range data.Chips {
		gpuMap[gpuDevice.ID] = gpuDevice
	}
	return gpuMap
}

func getNvidiaGPUs() ([]string, error) {
	var nvDevices []string
	deviceDirs, err := os.ReadDir(PCIDevicesRoot)
	if err != nil {
		return nil, err
	}

	for _, device := range deviceDirs {
		vendor, err := os.ReadFile(path.Join(PCIDevicesRoot, device.Name(), "vendor"))
		if err != nil {
			return nil, fmt.Errorf("failed to read pci device vendor name for %s: %w", device.Name(), err)
		}
		if strings.TrimSpace(string(vendor)) != NVIDIAVendorID {
			log.Tracef("Skipping device %s as it's not from the NVIDIA vendor", device.Name())
			continue
		}
		class, err := os.ReadFile(path.Join(PCIDevicesRoot, device.Name(), "class"))
		if err != nil {
			return nil, fmt.Errorf("failed to read pci device class name for %s: %w", device.Name(), err)
		}
		if strings.TrimSpace(string(class)) != PCIDeviceClassVGA && strings.TrimSpace(string(class)) != PCIDeviceClassGPU {
			log.Tracef("Skipping NVIDIA device %s as it's not of VGA/GPU device class", device.Name())
			continue
		}
		b, err := os.ReadFile(path.Join(PCIDevicesRoot, device.Name(), "device"))
		if err != nil {
			return nil, fmt.Errorf("failed to read pci device id for %s: %w", device.Name(), err)
		}

		deviceID, err := sanitizeDeviceID(string(b))
		if err != nil {
			return nil, fmt.Errorf("found invalid device id for %s: %w", device.Name(), err)
		}

		nvDevices = append(nvDevices, deviceID)
	}
	return nvDevices, nil
}

func sanitizeDeviceID(input string) (string, error) {
	var result string
	result = strings.TrimSpace(input)

	if len(result) != 6 {
		return "", fmt.Errorf("invalid device id format: %s", input)
	}

	// We only uppercase the device after the 0x part of the device id string to match the format in supported-gpus.json
	// For e.g. "0x1db6" becomes "0x1DB6"
	result = fmt.Sprintf("%s%s", result[0:2], strings.ToUpper(result[2:]))
	return result, nil
}
