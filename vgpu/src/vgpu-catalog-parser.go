package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"regexp"
	"strings"

	"gopkg.in/yaml.v2"

	log "github.com/sirupsen/logrus"
	cli "github.com/urfave/cli/v2"
)

type BranchDescriptor struct {
	Name       string        `yaml:"name"`
	Type       string        `yaml:"type"`
	Allow      AllowedBranch `yaml:"allow,omitempty"`
	Deny       DeniedBranch  `yaml:"deny,omitempty"`
	Properties []string      `yaml:"properties,omitempty"`
}

type DeniedBranch struct {
	Branch []string        `yaml:"branch,omitempty"`
	CPU    []string        `yaml:"cpu,omitempty"`
	GPU    []GPUDescriptor `yaml:"gpu,omitempty"`
}

type AllowedBranch struct {
	Branch []string        `yaml:"branch,omitempty"`
	CPU    []string        `yaml:"cpu,omitempty"`
	GPU    []GPUDescriptor `yaml:"gpu,omitempty"`
}

type GPUDescriptor struct {
	DevID string `yaml:"devid"`
	SSID  string `yaml:"ssid,omitempty"`
}

type DenyDriverDescriptor struct {
	CPU    []string        `yaml:"cpu,omitempty"`
	GPU    []GPUDescriptor `yaml:"gpu,omitempty"`
	Driver []Drivers       `yaml:"driver,omitempty"`
}

type Drivers struct {
	Version    string   `yaml:"version"`
	Hypervisor []string `yaml:"hypervisor,omitempty"`
	OS         []string `yaml:"os,omitempty"`
}

type AllowDriverDescriptor struct {
	CPU    []string        `yaml:"cpu,omitempty"`
	GPU    []GPUDescriptor `yaml:"gpu,omitempty"`
	Driver []Drivers       `yaml:"driver,omitempty"`
}

type DriverDescriptor struct {
	Version    string                `yaml:"version"`
	Date       string                `yaml:"date"`
	Branch     string                `yaml:"branch"`
	Type       string                `yaml:"type"`
	OS         []string              `yaml:"os,omitempty"`
	Deny       DenyDriverDescriptor  `yaml:"deny,omitempty"`
	Hypervisor []string              `yaml:"hypervisor,omitempty"`
	Allow      AllowDriverDescriptor `yaml:"allow,omitempty"`
}

// VGPUDriverCatalog defines the contents of vGPU Driver Catalog file
type VGPUDriverCatalog struct {
	Version int                `yaml:"version"`
	Date    string             `yaml:"date"`
	Branch  []BranchDescriptor `yaml:"branch"`
	Driver  []DriverDescriptor `yaml:"driver"`
}

// PCIDeviceInfo represents Nvidia PCI device info
type PCIDeviceInfo struct {
	deviceID    string
	vendor      string
	subsystemID string
}

var (
	hostDriverVersion  string
	hostDriverBranch   string
	installerDirectory string
	catalogFile        string
	// NVIDIA-Linux-x86_64-460.16-grid.run
	driverVersionRegex = regexp.MustCompile(`^NVIDIA-Linux-x86_64-(.*)-grid.run`)
)

const (
	// LogFile is the path for logging
	LogFile = "/var/log/vgpu-catalog-parser.log"
	// DefaultInstallerDirectory indicates default location where driver installers are located
	DefaultInstallerDirectory = "/drivers"
	// DefaultCatalogFile indicates default location where catalog file is located
	DefaultCatalogFile = "/drivers/vgpu-driver-catalog-file.yaml"
	// GuestCPU indicates default guest CPU type
	GuestCPU = "x86"
	// SysfsBasePath indicates base path for PCI devices info
	SysfsBasePath = "/sys/bus/pci/devices"
	// NvidiaVendorID represents Nvidia PCI vendor ID
	NvidiaVendorID = "0x10de"
)

func main() {
	// setup logger
	logFile, err := initializeLogger()
	if err != nil {
		log.Fatal(err.Error())
	}
	defer logFile.Close()

	// Create the top-level CLI
	c := cli.NewApp()
	c.Name = "vgpu-catalog-parser"
	c.Usage = "Find appropriate vGPU driver based on host driver version and branch"
	c.UsageText = " [-d | --host-driver-version] [-b | --host-driver-branch] [-i | --installer-directory] [-c | --catalog-file]"
	c.Version = "1.0.0"

	// Create the 'match' subcommand
	match := cli.Command{}
	match.Name = "match"
	match.Usage = "Find vGPU driver matching host driver version and branch"

	match.Action = func(c *cli.Context) error {
		return Match(c)
	}

	// Register the subcommands with the top-level CLI
	c.Commands = []*cli.Command{
		&match,
	}

	// Setup command flags
	commandFlags := []cli.Flag{
		&cli.StringFlag{
			Name:        "host-driver-version",
			Aliases:     []string{"d"},
			Usage:       "Host driver version",
			Value:       "",
			Destination: &hostDriverVersion,
			EnvVars:     []string{"VGPU_HOST_DRIVER_VERSION"},
		},
		&cli.StringFlag{
			Name:        "host-driver-branch",
			Aliases:     []string{"b"},
			Usage:       "Host driver branch",
			Value:       "",
			Destination: &hostDriverBranch,
			EnvVars:     []string{"VGPU_HOST_DRIVER_BRANCH"},
		},
		&cli.StringFlag{
			Name:        "installer-directory",
			Aliases:     []string{"i"},
			Usage:       "Directory containing driver installers",
			Value:       DefaultInstallerDirectory,
			Destination: &installerDirectory,
			EnvVars:     []string{"VGPU_INSTALLER_DIRECTORY"},
		},
		&cli.StringFlag{
			Name:        "catalog-file",
			Aliases:     []string{"c"},
			Usage:       "vGPU driver catalog file",
			Value:       DefaultCatalogFile,
			Destination: &catalogFile,
			EnvVars:     []string{"VGPU_DRIVER_CATALOG_FILE"},
		},
	}

	// Update the subcommand flags
	match.Flags = append([]cli.Flag{}, commandFlags...)

	// Run the top-level CLI
	if err := c.Run(os.Args); err != nil {
		log.Fatal(fmt.Errorf("Error: %v", err))
	}
}

func initializeLogger() (*os.File, error) {
	logFile, err := os.OpenFile(LogFile, os.O_APPEND|os.O_CREATE|os.O_RDWR, 0666)
	if err != nil {
		return nil, fmt.Errorf("error opening file %s: %v", LogFile, err)
	}
	// Log as JSON instead of the default ASCII formatter.
	log.SetFormatter(&log.JSONFormatter{})
	// Output to file instead of stdout
	log.SetOutput(logFile)

	// Only log the warning severity or above.
	log.SetLevel(log.DebugLevel)
	return logFile, nil
}

// Match vGPU driver version from given host driver version and branch
func Match(c *cli.Context) error {
	log.Infof("Starting 'match' with %v", c.App.Name)

	// load catalog file
	driverCatalog, err := LoadCatalog()
	if err != nil {
		return fmt.Errorf("unable to load catalog file: %v", err)
	}

	// find available drivers present in the installerDirectory
	availableDrivers, err := FindAvailableDrivers()
	if err != nil {
		return fmt.Errorf("unable to find available drivers downloaded in the image: %v", err)
	}

	// find device id and subsystem id of local GPU device
	pciDeviceInfo, err := getPCIDeviceInfo()
	if err != nil {
		return fmt.Errorf("unable to find local nvidia pci device info: %v", err)
	}

	version, err := FindMatch(driverCatalog, availableDrivers, pciDeviceInfo)
	if err != nil {
		return fmt.Errorf("unable to find matching driver version: %v", err)
	}

	log.Infof("Found matching vGPU guest driver version %s", version)

	// set via both env and output
	os.Setenv("DRIVER_VERSION", version)
	fmt.Println("DRIVER_VERSION=" + version)

	log.Infof("Completed 'match' with %v", c.App.Name)
	return nil
}

// FindAvailableDrivers returns driver versions of installers downloaded locally
func FindAvailableDrivers() ([]string, error) {
	var availableDrivers []string
	files, err := ioutil.ReadDir(installerDirectory)
	if err != nil {
		return nil, fmt.Errorf("unable to list files from installer directory %s: %v", installerDirectory, err)
	}

	for _, file := range files {
		// fetch driver version from filename
		fmt.Println(file.Name())
		driverVersion := driverVersionRegex.FindStringSubmatch(path.Base(file.Name()))
		if len(driverVersion) > 0 {
			availableDrivers = append(availableDrivers, driverVersion[0])
		}
	}
	return availableDrivers, nil
}

// FindMatch matches the vgpu driver version based on host driver version and branch
func FindMatch(driverCatalog *VGPUDriverCatalog, availbleDriverList []string, pciDeviceInfo *PCIDeviceInfo) (string, error) {
	var hostBranchInfo BranchDescriptor
	var hostDriverInfo DriverDescriptor
	var guestBranchInfoList []BranchDescriptor
	var guestDriverInfoList []DriverDescriptor

	// Process branch descriptors to select one that describes the installed host driver's branch, and a list
	// of possible matching guest branch descriptors

	for _, branch := range driverCatalog.Branch {
		foundHostBranchInfo := false
		if branch.Type == "host" {
			log.Debugf("checking host branch descriptor %s", branch.Name)
			if branch.Name == hostDriverBranch {
				if foundHostBranchInfo {
					// already found host branch info, log warning and skip
					log.Warnf("Duplicate host branch info found for branch name %s", branch.Name)
					continue
				}

				// check if allowList cpu list is present and doesn't match guestGPU, or denyList cpu list is present and matches guestGPU
				if !foundGPU(branch.Allow.GPU, pciDeviceInfo) {
					continue
				}
				if foundGPU(branch.Deny.GPU, pciDeviceInfo) {
					continue
				}

				// check if allowList cpu list is present and doesn't match guestCPU, or denyList cpu list is present and matches guestCPU
				if !foundCPU(branch.Allow.CPU) {
					continue
				}
				if foundCPU(branch.Deny.CPU) {
					continue
				}

				hostBranchInfo = branch
				foundHostBranchInfo = true
			}
		} else if branch.Type == "guest" {
			log.Debugf("checking guest branch descriptor %s", branch.Name)
			// check if allowList cpu list is present and doesn't match guestGPU, or denyList cpu list is present and matches guestGPU
			if !foundGPU(branch.Allow.GPU, pciDeviceInfo) {
				continue
			}
			if foundGPU(branch.Deny.GPU, pciDeviceInfo) {
				continue
			}

			// check if allowList cpu list is present and doesn't match guestCPU, or denyList cpu list is present and matches guestCPU
			if !foundCPU(branch.Allow.CPU) {
				continue
			}
			if foundCPU(branch.Deny.CPU) {
				continue
			}

			if len(branch.Deny.Branch) > 0 {
				if foundBranch(branch.Deny.Branch, hostDriverBranch) {
					log.Infof("host branch %s matches guest denied branch list for %s, ignore...", hostDriverBranch, branch.Name)
					continue
				}
			}
			if len(branch.Allow.Branch) > 0 {
				if !foundBranch(branch.Allow.Branch, hostDriverBranch) {
					log.Infof("host branch %s doesn't match with guest allowed branch list for %s, ignore...", hostDriverBranch, branch.Name)
					continue
				}
				guestBranchInfoList = append(guestBranchInfoList, branch)
			}
		}
	}

	if hostBranchInfo.Name == "" {
		return "", fmt.Errorf("Could not find matching host branch %s in catalog file", hostDriverBranch)
	}
	log.Debugf("selected hostBranchInfo for %s", hostBranchInfo.Name)

	if len(guestBranchInfoList) == 0 {
		return "", fmt.Errorf("Could not find guest branch info matching host branch %s in catalog file", hostDriverBranch)
	}
	log.Debugf("filtered %d guest branch info descriptors", len(guestBranchInfoList))

	// Filter guestBranchInfoList to remove any guest branches made ineligible by the host branch's allow / deny lists.
	for i, guestBranch := range guestBranchInfoList {
		if !foundBranch(hostBranchInfo.Allow.Branch, guestBranch.Name) {
			log.Debugf("Removing guest branch %s as not found in allowed list of host branch", guestBranch.Name)
			// remove guest branch
			guestBranchInfoList = append(guestBranchInfoList[:i], guestBranchInfoList[i+1])
			continue
		}

		for _, deniedGuestBranch := range hostBranchInfo.Deny.Branch {
			if deniedGuestBranch == guestBranch.Name {
				log.Debugf("Removing guest branch %s as found in denied list of host branch", guestBranch.Name)
				// remove guest branch
				guestBranchInfoList = append(guestBranchInfoList[:i], guestBranchInfoList[i+1])
				continue
			}
		}
	}

	// Process driver descriptors to produce a filtered list of candidate guest drivers and a driver descriptor
	// for the host driver
	for _, driver := range driverCatalog.Driver {
		if driver.Type == "guest" {
			// continue if allowList cpu list is present and doesn't match guestCPU, or denyList cpu list is present and matches guestCPU
			if !foundCPU(driver.Allow.CPU) {
				continue
			}
			if foundCPU(driver.Deny.CPU) {
				continue
			}

			//  continue if allowList gpu list is present and doesn't match guest4PartId, or denyList gpu list is present and matches guest4PartId
			if !foundGPU(driver.Allow.GPU, pciDeviceInfo) {
				continue
			}
			if foundGPU(driver.Deny.GPU, pciDeviceInfo) {
				continue
			}

			// continue is supported driver for Linux OS is not found
			if !foundLinuxOS(driver.OS) {
				continue
			}

			if len(driver.Allow.Driver) > 0 {
				if foundDriver(driver.Allow.Driver, hostDriverVersion) {
					guestDriverInfoList = append(guestDriverInfoList, driver)
					continue
				}
			}
			if len(driver.Deny.Driver) > 0 {
				if foundDriver(driver.Deny.Driver, hostDriverVersion) {
					continue
				}
			}
			for _, guestBranchDescriptor := range guestBranchInfoList {
				if guestBranchDescriptor.Name == driver.Branch {
					guestDriverInfoList = append(guestDriverInfoList, driver)
				}
			}
		} else if driver.Type == "host" {
			// continue if allowList cpu list is present and doesn't match guestCPU, or denyList cpu list is present and matches guestCPU
			if !foundCPU(driver.Allow.CPU) {
				continue
			}
			if foundCPU(driver.Deny.CPU) {
				continue
			}

			//  continue if allowList gpu list is present and doesn't match guest4PartId, or denyList gpu list is present and matches guest4PartId
			if !foundGPU(driver.Allow.GPU, pciDeviceInfo) {
				continue
			}
			if foundGPU(driver.Deny.GPU, pciDeviceInfo) {
				continue
			}
			if driver.Branch == hostDriverBranch && driver.Version == hostDriverVersion {
				if hostDriverInfo.Version != "" {
					// already found driver info, log warning and skip
					log.Warnf("Duplicate driver info found for branch name %s version %s", hostDriverInfo.Branch, hostDriverInfo.Version)
					continue
				}
				hostDriverInfo = driver
			}
		}
	}

	// Filter guestDriverInfoList to remove any guest drivers that are unavailable, or are made ineligible by a host driver's
	// allow / deny lists.
	for i, guestDriver := range guestDriverInfoList {
		if !foundAvailableDriver(availbleDriverList, guestDriver.Version) {
			// remove guest driver info
			log.Debugf("removing guest driver info list %s as its not available", guestDriver.Version)
			if i < len(guestDriverInfoList)-1 {
				guestDriverInfoList = append(guestDriverInfoList[:i], guestDriverInfoList[i+1])
			} else {
				guestDriverInfoList = guestDriverInfoList[:i]
			}
			continue
		}
		if hostDriverInfo.Version != "" {
			if len(hostDriverInfo.Allow.Driver) > 0 {
				if foundDriver(hostDriverInfo.Allow.Driver, guestDriver.Version) {
					continue
				}
				// remove guest driver from guest driver info list
				log.Debugf("removing guest driver info list %s", guestDriver.Version)
				if i < len(guestDriverInfoList)-1 {
					guestDriverInfoList = append(guestDriverInfoList[:i], guestDriverInfoList[i+1])
				} else {
					guestDriverInfoList = guestDriverInfoList[:i]
				}
				guestDriverInfoList = append(guestDriverInfoList[:i], guestDriverInfoList[i+1])
				continue
			}
			if len(hostDriverInfo.Deny.Driver) > 0 {
				if foundDriver(hostDriverInfo.Deny.Driver, guestDriver.Version) {
					log.Debugf("removing guest driver info list %s as its denied", guestDriver.Version)
					// remove guest driver from guest driver info list
					if i < len(guestDriverInfoList)-1 {
						guestDriverInfoList = append(guestDriverInfoList[:i], guestDriverInfoList[i+1])
					} else {
						guestDriverInfoList = guestDriverInfoList[:i]
					}
				}
				continue
			}
		}
	}

	// Pick driver from guestDriverInfoList based on match criteria
	for _, driver := range guestDriverInfoList {
		if driver.Branch == hostDriverBranch {
			return driver.Version, nil
		}
	}

	// TODO: Identify the most recent guest driver on some specified branch that is compatible with the host driver
	return "", fmt.Errorf("Unable to find vGPU driver version matching host driver version %s and branch %s", hostDriverVersion, hostDriverBranch)
}

// LoadCatalog loads the vgpu driver catalog file
func LoadCatalog() (*VGPUDriverCatalog, error) {
	log.Infof("Loading catalog file: %v", catalogFile)

	_, err := os.Stat(catalogFile)
	if err != nil {
		return nil, fmt.Errorf("Catalog file %s not found", catalogFile)
	}

	yamlFile, err := ioutil.ReadFile(catalogFile)
	if err != nil {
		return nil, fmt.Errorf("Failed to read catalog file %s", catalogFile)
	}

	var driverCatalog VGPUDriverCatalog

	err = yaml.Unmarshal(yamlFile, &driverCatalog)
	if err != nil {
		return nil, fmt.Errorf("Error un-marshalling catalog file: %v", err)
	}

	log.Infof("Successfully loaded catalog file")

	return &driverCatalog, nil
}

func getPCIDeviceInfo() (*PCIDeviceInfo, error) {
	// fetch pci devices
	devices, err := ioutil.ReadDir(SysfsBasePath)
	if err != nil {
		return nil, err
	}

	for _, device := range devices {
		vendor, err := ioutil.ReadFile(path.Join(SysfsBasePath, device.Name(), "vendor"))
		if err != nil {
			return nil, fmt.Errorf("failed to read device vendor name for %s: %v", device.Name(), err)
		}
		if strings.TrimSpace(string(vendor)) != NvidiaVendorID {
			continue
		}
		log.Debugf("found nvidia device %s", device.Name())
		// fetch subsystem-id and device-id
		deviceID, err := ioutil.ReadFile(path.Join(SysfsBasePath, device.Name(), "device"))
		if err != nil {
			return nil, fmt.Errorf("failed to read device id for %s: %v", device.Name(), err)
		}
		deviceIDStr := strings.TrimSpace(string(deviceID))
		log.Debugf("got pci device id as %s for device %s", deviceIDStr, device.Name())
		subsystemID, err := ioutil.ReadFile(path.Join(SysfsBasePath, device.Name(), "subsystem_device"))
		if err != nil {
			return nil, fmt.Errorf("failed to read device subsystem device id for %s: %v", device.Name(), err)
		}
		subsystemIDStr := strings.TrimSpace(string(subsystemID))
		log.Debugf("got pci subsystem device id as %s for device %s", subsystemIDStr, device.Name())
		return &PCIDeviceInfo{vendor: NvidiaVendorID, deviceID: deviceIDStr, subsystemID: subsystemIDStr}, nil
	}
	return nil, nil
}

func foundGPU(gpuList []GPUDescriptor, pciDeviceInfo *PCIDeviceInfo) bool {
	if pciDeviceInfo.deviceID != "" && pciDeviceInfo.subsystemID != "" {
		for _, gpu := range gpuList {
			if strings.ToLower(gpu.DevID) == pciDeviceInfo.deviceID || strings.ToLower(gpu.SSID) == pciDeviceInfo.subsystemID {
				return true
			}
		}
	}
	return false
}

func foundCPU(cpuList []string) bool {
	for _, cpu := range cpuList {
		if cpu == GuestCPU {
			return true
		}
	}
	return false
}

func foundBranch(branchList []string, requiredBranch string) bool {
	for _, branch := range branchList {
		if branch == requiredBranch {
			return true
		}
	}
	return false
}

func foundLinuxOS(osList []string) bool {
	for _, os := range osList {
		if os == "Linux" {
			return true
		}
	}
	return false
}

func foundDriver(drivers []Drivers, requiredDriverVersion string) bool {
	for _, driver := range drivers {
		if driver.Version == requiredDriverVersion {
			return true
		}
	}
	return false
}

func foundAvailableDriver(availableDriverList []string, requiredDriver string) bool {
	for _, driver := range availableDriverList {
		if driver == requiredDriver {
			return true
		}
	}
	return false
}
