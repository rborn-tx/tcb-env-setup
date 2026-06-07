# tcb-env-setup

Environment setup script for running TorizonCore Builder from its Docker image.

The script prepares a shell function named `torizoncore-builder` that runs the container with the expected defaults for volumes, networking, and workspace access.

## Prerequisites

Before using the setup script, make sure the host system has:

- `docker`
- `curl`

The script also expects to be sourced from a shell session. It supports command completion only on `bash` and `zsh`.

## Interactive Mode (Quick Start)

`tcb-env-setup.sh` must be sourced into your current shell session. Run the script with no arguments:

```bash
. tcb-env-setup.sh
```

In interactive mode, the script checks local and remote versions and may ask whether you want to update to the latest official release.

Use this mode when you are working manually in a terminal and want the script to guide the version selection.

If setup succeeds, the `torizoncore-builder` command becomes available in the current shell.
You can then invoke TorizonCore Builder as if it were a normal command:

```bash
torizoncore-builder -h
```

The setup is session-local. You need to source the script again in every new shell session.

### Notes

- You must source the script with `.` or `source`. Executing it directly will fail and will not define `torizoncore-builder`.
- Interactive mode requires `stdin` to be attached to a TTY.
- You must run the setup script again in each new shell session.
- On Linux, the generated Docker command uses `--network=host` by default.
- On Windows environments, host networking is disabled and server-style commands may require explicit port publishing via `-- <docker_options>`.

## Non-Interactive Mode

Use non-interactive mode when running from automation, CI, or wrapper scripts.

### Use the latest remote official version

```bash
. tcb-env-setup.sh -a remote
```

This selects the latest official version of TorizonCore Builder available online and pulls it if needed.

### Use the latest local version

```bash
. tcb-env-setup.sh -a local
```

This selects the latest locally available TorizonCore Builder image and does not check online for a newer version.

This is the fastest mode when you already have the required image locally.

### Use a specific tag

```bash
. tcb-env-setup.sh -t 3.11.0
```

This selects the exact image tag you provide and pulls it if needed.

`-a` and `-t` are mutually exclusive.

## CI Example

A typical CI-friendly invocation is:

```bash
. tcb-env-setup.sh -a remote -c -P
```

Why these flags are useful in CI:

- `-a remote`: Avoids prompts and always selects the latest official version.
- `-c`: Skips shell completion setup.
- `-P`: Exports `torizoncorebuilder` instead of `torizoncore-builder`, which is safer in more minimal POSIX shell environments.

Example usage:

```bash
. tcb-env-setup.sh -a remote -c -P
torizoncorebuilder --help
```

## Early-Access Usage

Toradex regularly publishes an early-access version of TorizonCore Builder. This version may contain bug fixes and features that are not yet officially released.

Use it only when:

- You are validating a fix provided by Toradex support.
- You explicitly need an early-access feature (this is commonly the case with Torizon OS features that are in the early-access status).
- You understand that behavior and interfaces may still change.

To use it:

```bash
. tcb-env-setup.sh -t early-access
```

### Early-Access Notes

- Early-access is not treated as the latest official release.
- Shell completion may not be loaded for this tag.
- New functionality in early-access may not yet be documented.

## Options

The script supports the following options:

- `-a <local|remote>`
  Select non-interactive auto mode.
- `-t <version-tag>`
  Select a specific image tag.
- `-d`
  Disable the default deployment volume.
- `-s <storage>`
  Use a specific storage location. This must be either:
  an absolute directory path, or a Docker volume name.
- `-n`
  Disable `--network=host` on Linux.
- `-c`
  Disable shell completion loading.
- `-P`
  Export `torizoncorebuilder` instead of `torizoncore-builder`.
- `-- <docker_options>`
  Forward extra options directly to `docker run`.
- `-h`
  Show help.

## Exported Commands and Variables

After successful setup, the script exports a command function and some helper variables.

- Function `torizoncore-builder` (or `torizoncorebuilder` when `-P` is passed):

  This function wraps `docker run` and automatically adds `-i` and `-t` when the current terminal supports them.

- Variable `TCB_COMMAND`:

  `TCB_COMMAND` contains the full non-interactive `docker run` command line, excluding the arguments intended for TorizonCore Builder itself.

  Example: display the help of the `platform` command:

  ```bash
  eval "${TCB_COMMAND}" platform --help
  ```

- Variables `TCB_COMMAND_BASE` and `TCB_COMMAND_ARGS`:

  `TCB_COMMAND` is composed from these two variables.

  - `TCB_COMMAND_BASE`: The base runtime command, typically `docker run`.
  - `TCB_COMMAND_ARGS`: The generated Docker arguments plus the selected image reference.

  Example: force TTY allocation manually when invoking the `images serve` command:

  ```bash
  eval "${TCB_COMMAND_BASE} -it ${TCB_COMMAND_ARGS}" images serve
  ```

## Completion Behavior

If completion is enabled, the script tries to load the completion script automatically.

Completion may be unavailable when:

- Switch `-c` was passed.
- The current shell is not `bash` or `zsh`.
- The selected image tag is not the latest official release.
- The completion script cannot be retrieved from the container image or fallback source.

Completion is optional and does not affect the ability to run TorizonCore Builder itself.

## Contributing

See [CONTRIBUTING.md](/opt/shared/rborin/torgit/tcb-env-setup/CONTRIBUTING.md).

## License

This project is MIT licensed.

This README document is Copyright (C) 2021 Toradex AG.
