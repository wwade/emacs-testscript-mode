# testscript-mode

An Emacs major mode for editing
[testscript](https://github.com/rogpeppe/go-internal/tree/master/testscript)
files that use the [txtar](https://pkg.go.dev/golang.org/x/tools/txtar) archive
format.

Testscript is a shell-like testing framework used extensively in the Go
ecosystem for integration testing of CLI tools. Each `.txtar` file contains a
script section (commands to execute) followed by zero or more embedded file
sections delimited by `-- FILENAME --` markers.

## Features

- **Syntax highlighting** for built-in commands, condition guards, negation
  prefixes, environment variables, single-quoted strings, comments, and file
  markers
- **Imenu support** for navigating between embedded file sections
- **Navigation commands** to jump between file sections
- **Comment support** via standard Emacs comment commands

## Installation

### From MELPA (planned)

```elisp
(use-package testscript-mode)
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-testscript-mode")
(require 'testscript-mode)
```

## Usage

The mode activates automatically for `.txtar` files. You can also enable it
manually with `M-x testscript-mode`.

### Key bindings

| Key       | Command                            | Description                     |
|-----------|------------------------------------|---------------------------------|
| `C-c C-n` | `testscript-next-file-section`     | Jump to next file marker        |
| `C-c C-p` | `testscript-previous-file-section` | Jump to previous file marker    |

### Highlighted syntax elements

| Element              | Example                  | Face                          |
|----------------------|--------------------------|-------------------------------|
| Built-in commands    | `exec`, `stdout`, `env`  | `font-lock-keyword-face`      |
| Condition guards     | `[linux]`, `[!exec:cat]` | `font-lock-preprocessor-face` |
| Negation/optional    | `!`, `?`                 | `font-lock-negation-char-face`|
| Environment vars     | `$HOME`, `${VAR}`        | `font-lock-variable-name-face`|
| Single-quoted strings| `'pattern'`              | `font-lock-string-face`       |
| Comments             | `# comment`              | `font-lock-comment-face`      |
| File markers         | `-- file.txt --`         | `testscript-file-marker-face` |
| Background operator  | `&`                      | `font-lock-type-face`         |

## Testscript format

A txtar file has two parts:

1. **Script section** -- commands executed line by line
2. **File sections** -- embedded files created before script execution

```
# This is a comment
env HOME=/tmp
exec mycommand --flag $HOME
stdout 'expected output'
! stderr .

[linux] exec uname

-- input.txt --
file content here
-- expected.txt --
expected output
```

See the [testscript documentation](https://pkg.go.dev/github.com/rogpeppe/go-internal/testscript)
for the full command reference.

## Development

```bash
# Run all checks (compile + test + checkdoc)
make check

# Run tests only
make test

# Byte-compile
make compile

# Checkdoc
make checkdoc
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
