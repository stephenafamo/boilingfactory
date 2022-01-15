package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"github.com/spf13/viper"
	"github.com/volatiletech/sqlboiler/v4/importers"
	"golang.org/x/mod/modfile"
)

type commandFailure string

func (c commandFailure) Error() string {
	return string(c)
}

// goModInfo returns the main module's root directory
// and the parsed contents of the go.mod file.
func goModInfo() (*modfile.File, error) {
	goModPath, err := findGoMod()
	if err != nil {
		return nil, fmt.Errorf("cannot find main module: %w", err)
	}

	data, err := ioutil.ReadFile(goModPath)
	if err != nil {
		return nil, fmt.Errorf("cannot read main go.mod file: %w", err)
	}

	modf, err := modfile.Parse(goModPath, data, nil)
	if err != nil {
		return nil, fmt.Errorf("could not parse go.mod: %w", err)
	}

	return modf, nil
}

func findGoMod() (string, error) {
	out, err := runCmd(".", "go", "env", "GOMOD")
	if err != nil {
		return "", err
	}
	out = strings.TrimSpace(out)
	if out == "" {
		return "", errors.New("no go.mod file found in any parent directory")
	}
	return strings.TrimSpace(out), nil
}

func runCmd(dir string, name string, args ...string) (string, error) {
	var outData, errData bytes.Buffer

	c := exec.Command(name, args...)
	c.Stdout = &outData
	c.Stderr = &errData
	c.Dir = dir
	err := c.Run()
	if err == nil {
		return outData.String(), nil
	}
	if _, ok := err.(*exec.ExitError); ok && errData.Len() > 0 {
		return "", errors.New(strings.TrimSpace(errData.String()))
	}
	return "", fmt.Errorf("cannot run %q: %v", append([]string{name}, args...), err)
}

func allKeys(prefix string) []string {
	keys := make(map[string]bool)

	prefix += "."

	for _, e := range os.Environ() {
		splits := strings.SplitN(e, "=", 2)
		key := strings.ReplaceAll(strings.ToLower(splits[0]), "_", ".")

		if strings.HasPrefix(key, prefix) {
			keys[strings.ReplaceAll(key, prefix, "")] = true
		}
	}

	for _, key := range viper.AllKeys() {
		if strings.HasPrefix(key, prefix) {
			keys[strings.ReplaceAll(key, prefix, "")] = true
		}
	}

	keySlice := make([]string, 0, len(keys))
	for k := range keys {
		keySlice = append(keySlice, k)
	}
	return keySlice
}

func copyTemplates(dir string) error {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 0, ' ', tabwriter.Debug)
	defer w.Flush()

	return fs.WalkDir(templates, ".", func(path string, info fs.DirEntry, err error) error {
		if err != nil {
			return fmt.Errorf("an error was passed to the walkFunc: %w", err)
		}

		if info.IsDir() {
			return nil
		}

		relPath := strings.TrimPrefix(path, "templates/")

		tplFile, err := templates.Open(path)
		if err != nil {
			return fmt.Errorf("error when opening template file: %w", err)
		}
		defer tplFile.Close()

		newFile, err := os.Create(filepath.Join(dir, relPath))
		if err != nil {
			return fmt.Errorf("error when creating new file: %w", err)
		}
		defer newFile.Close()

		_, err = io.Copy(newFile, tplFile)
		if err != nil {
			return fmt.Errorf("error when copying file: %w", err)
		}

		return nil
	})
}

func configureImports() importers.Collection {
	imports := importers.NewDefaultImports()

	imports.All = importers.Set{
		Standard: []string{`"fmt"`},
		ThirdParty: []string{
			fmt.Sprintf(`models "%s"`, modelsPkg),
			`"github.com/volatiletech/sqlboiler/v4/boil"`,
			`"github.com/volatiletech/sqlboiler/v4/queries"`,
		},
	}
	imports.Singleton["boilingfactory_main"] = importers.Set{
		Standard: []string{`"fmt"`, `"context"`, `"reflect"`},
	}

	return imports
}
