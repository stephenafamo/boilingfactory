package main

import (
	"embed"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/volatiletech/sqlboiler/v4/boilingcore"
	"github.com/volatiletech/sqlboiler/v4/drivers"
)

//go:embed templates
var templates embed.FS

const boilingfactoryVersion = "0.1.0"

var (
	flagConfigFile   string
	tempTemplatesDir string
	modelsPkg        string
	cmdState         *boilingcore.State
	cmdConfig        *boilingcore.Config
)

func initConfig() {
	if len(flagConfigFile) != 0 {
		viper.SetConfigFile(flagConfigFile)
		if err := viper.ReadInConfig(); err != nil {
			fmt.Println("Can't read config:", err)
			os.Exit(1)
		}
		return
	}

	var err error
	viper.SetConfigName("boilingfactory")

	configHome := os.Getenv("XDG_CONFIG_HOME")
	homePath := os.Getenv("HOME")
	wd, err := os.Getwd()
	if err != nil {
		wd = "."
	}

	configPaths := []string{wd}
	if len(configHome) > 0 {
		configPaths = append(configPaths, filepath.Join(configHome, "sqlboiler"))
	} else {
		configPaths = append(configPaths, filepath.Join(homePath, ".config/sqlboiler"))
	}

	for _, p := range configPaths {
		viper.AddConfigPath(p)
	}

	// Ignore errors here, fallback to other validation methods.
	// Users can use environment variables if a config is not found.
	_ = viper.ReadInConfig()
}

func main() {
	// Too much happens between here and cobra's argument handling, for
	// something so simple just do it immediately.
	for _, arg := range os.Args {
		if arg == "--version" {
			fmt.Println("Boilingfactory v" + boilingfactoryVersion)
			return
		}
	}

	// Set up the cobra root command
	var rootCmd = &cobra.Command{
		Use:   "boilingfactory [flags] <driver>",
		Short: "Boilingfactory generates factoryer for your SQLBoiler models.",
		Long: "Boilingfactory generates factoryer for your SQLBoiler models.\n" +
			`Complete documentation is available at http://github.com/stephenafamo/boilingfactory`,
		Example:       `boilingfactory psql`,
		PreRunE:       preRun,
		RunE:          run,
		PostRunE:      postRun,
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	cobra.OnInitialize(initConfig)

	// Set up the cobra root command flags
	rootCmd.PersistentFlags().StringVarP(&flagConfigFile, "config", "c", "", "Filename of config file to override default lookup")
	rootCmd.PersistentFlags().String("sqlboiler-models", "", "The package of your generated models. Needed to import them properly in the factoryer files.")
	rootCmd.PersistentFlags().StringP("output", "o", "factory", "The name of the folder to output to")
	rootCmd.PersistentFlags().StringP("pkgname", "p", "factory", "The name you wish to assign to your generated package")
	rootCmd.PersistentFlags().BoolP("debug", "d", false, "Debug mode prints stack traces on error")
	rootCmd.PersistentFlags().BoolP("no-tests", "", false, "Disable generated go test files")
	rootCmd.PersistentFlags().BoolP("add-enum-types", "", false, "Enable generation of types for enums")
	rootCmd.PersistentFlags().BoolP("version", "", false, "Print the version")
	rootCmd.PersistentFlags().BoolP("wipe", "", false, "Delete the output folder (rm -rf) before generation to ensure sanity")

	// hide flags not recommended for use
	rootCmd.PersistentFlags().MarkHidden("no-tests")       // no generated tests right now
	rootCmd.PersistentFlags().MarkHidden("add-enum-types") // not yet enabled on SQLBoiler

	viper.BindPFlags(rootCmd.PersistentFlags())
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_", "-", "_"))
	viper.AutomaticEnv()

	if err := rootCmd.Execute(); err != nil {
		if e, ok := err.(commandFailure); ok {
			fmt.Printf("Error: %v\n\n", string(e))
			rootCmd.Help()
		} else if !viper.GetBool("debug") {
			fmt.Printf("Error: %v\n", err)
		} else {
			fmt.Printf("Error: %+v\n", err)
		}

		os.Exit(1)
	}
}

func preRun(cmd *cobra.Command, args []string) error {
	var err error

	// set the models pkg path
	modelsPkg = viper.GetString("sqlboiler-models")
	if modelsPkg == "" {
		modFile, err := goModInfo()
		if err != nil {
			return commandFailure("must provide the models package (--sqlboiler-models) or be in a go module")
		}

		modelsPkg = modFile.Module.Mod.Path + "/models"
	}

	if len(args) == 0 {
		return commandFailure("must provide a driver name")
	}

	driverName := args[0]
	driverPath := args[0]

	if strings.ContainsRune(driverName, os.PathSeparator) {
		driverName = strings.Replace(filepath.Base(driverName), "sqlboiler-", "", 1)
		driverName = strings.Replace(driverName, ".exe", "", 1)
	} else {
		driverPath = "sqlboiler-" + driverPath
		if p, err := exec.LookPath(driverPath); err == nil {
			driverPath = p
		}
	}

	driverPath, err = filepath.Abs(driverPath)
	if err != nil {
		return fmt.Errorf("could not find absolute path to driver: %w", err)
	}
	drivers.RegisterBinary(driverName, driverPath)

	// Create the directior
	tempTemplatesDir, err = ioutil.TempDir("", "boilingfactory")
	if err != nil {
		return fmt.Errorf("could not create temp directory: %w", err)
	}

	// Add a folder for our singleton templates
	if err := os.Mkdir(tempTemplatesDir+"/singleton", 0755); err != nil {
		return fmt.Errorf("could not make singleton temp directory: %w", err)
	}

	// Write template files to this directory
	if err := copyTemplates(tempTemplatesDir); err != nil {
		return fmt.Errorf("could not copy factory template files: %w", err)
	}

	cmdConfig = &boilingcore.Config{
		DriverName:   driverName,
		OutFolder:    viper.GetString("output"),
		PkgName:      viper.GetString("pkgname"),
		Debug:        viper.GetBool("debug"),
		NoTests:      viper.GetBool("no-tests"),
		Wipe:         viper.GetBool("wipe"),
		Aliases:      boilingcore.ConvertAliases(viper.Get("aliases")),
		TypeReplaces: boilingcore.ConvertTypeReplace(viper.Get("types")),
		Version:      "boilingfactory-" + boilingfactoryVersion,

		// Things we specifically override
		TemplateDirs:      []string{tempTemplatesDir},
		NoDriverTemplates: true,
	}

	if cmdConfig.Debug {
		fmt.Fprintln(os.Stderr, "using driver:", driverPath)
		fmt.Fprintln(os.Stderr, "using models:", modelsPkg)
	}

	// Configure the driver
	cmdConfig.DriverConfig = map[string]interface{}{
		"whitelist": viper.GetStringSlice(driverName + ".whitelist"),
		"blacklist": viper.GetStringSlice(driverName + ".blacklist"),
	}

	keys := allKeys(driverName)
	for _, key := range keys {
		if key != "blacklist" && key != "whitelist" {
			prefixedKey := fmt.Sprintf("%s.%s", driverName, key)
			cmdConfig.DriverConfig[key] = viper.Get(prefixedKey)
		}
	}

	cmdConfig.Imports = configureImports()

	cmdState, err = boilingcore.New(cmdConfig)
	return err
}

func run(cmd *cobra.Command, args []string) error {
	return cmdState.Run()
}

func postRun(cmd *cobra.Command, args []string) error {
	err := os.RemoveAll(tempTemplatesDir)
	if err != nil {
		return fmt.Errorf("could not clean up temp templates directory: %w", err)
	}

	return cmdState.Cleanup()
}
