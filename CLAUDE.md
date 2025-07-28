# Zshctl - Advanced CLI Framework for Zsh

## Overview

Zshctl is Alan's sophisticated framework for building command-line tools in Zsh. It provides the infrastructure for creating complex CLI applications with proper argument parsing, command delegation, shell completions, and documentation generation.

## Philosophy

Instead of using Go/Python/Rust for CLI tools, why not use the shell itself? Zshctl makes Zsh a first-class language for building production CLI applications.

## Core Features

### 1. Argument Parsing (`args`)
Sophisticated argument parser that generates Zsh code for parsing command-line arguments:
```zsh
eval "$(args -UC -bx h,help v,verbose -- "$@")"
```

Features:
- Short and long options (`-h, --help`)
- Various argument types:
  - Flags: `h,help` (boolean)
  - Values: `n,name:` (takes an argument)
  - Arrays: `f,file@` (multiple values)
  - Counters: `v,verbose#` (counts occurrences)
  - Toggles: `q,quiet!` (can be negated with --no-quiet)
- Custom variable names: `o_repository=b,barnyard:`
- Automatic help generation

### 2. Command Delegation System
Hierarchical command structure with automatic routing:
```zsh
function execute:gce {
    eval "$(args -UC -bx h,help -- "$@")"
    delegate "$@"
}

function execute:gce:key:create {
    # Implementation for 'acrectl gce key create'
}
```

### 3. Shell Completion Generation
Generates completions for both Bash and Zsh:
- Rich completions with descriptions
- File filtering
- Directory completion
- Active help support

### 4. Documentation System
Inline documentation using special blocks:
```zsh
# ___ execute:gce _ description ___
# Manage Google Cloud Engine resources.
# ___ execute:gce _ man ___
# .SH NAME
# acrectl\ gce \- manage Google Cloud Engine resources
# ...
# ___
```

### 5. Include System
Modular code organization:
```zsh
include parse    # Loads from include/parse.zsh
include heredoc  # Loads from include/heredoc.zsh
```

### 6. Shebang Support
Can create standalone scripts that use zshctl infrastructure:
```zsh
#!/usr/bin/env zshctl
# Your script using zshctl features
```

## Architecture

### Directory Structure
```
share/
  zshctl/
    zshctl/
      commands/        # Command implementations
        version/
          command.zsh
        completion/
          command.zsh
          bash/
            command.zsh
            complete.bash
          zsh/
            command.zsh
            complete.zsh
      include/         # Reusable modules
        parse.zsh
        heredoc.zsh
        catch.zsh
```

### Command Resolution
1. Commands are discovered from `share/{program}/*/commands/**/command.zsh`
2. Function names follow pattern: `execute:{command}:{subcommand}:{...}`
3. The `delegate` function automatically routes to the correct implementation

### Compilation Support
Zshctl supports compiling Zsh scripts for faster loading:
- `lib/compile.zsh` handles compilation
- Compiled functions are autoloaded
- Distribution packages can include pre-compiled code

## Integration with Acres Infrastructure

Zshctl is the foundation for `acrectl`, the main operational CLI tool at Acres. It demonstrates how sophisticated tooling can be built entirely in Zsh without sacrificing features typically found in compiled languages.

## Advanced Features

### Parse Module
Provides the sophisticated `args` function for argument parsing that generates efficient Zsh code rather than parsing at runtime.

### Heredoc Module
Enhanced heredoc handling with proper indentation stripping:
```zsh
heredoc <<'    EOF'
    This text will have
    leading spaces stripped
    based on minimum indentation
EOF
```

### Error Handling
The `catch` module provides structured error handling:
```zsh
catch {
    # Code that might fail
} {
    # Error handler
}
```

## Benefits

1. **No compilation step** - It's just Zsh scripts
2. **Native shell integration** - No subprocess overhead
3. **Rich completions** - First-class support for shell completion
4. **Self-documenting** - Documentation lives with code
5. **Modular** - Include system for code reuse
6. **Fast** - Optional compilation for performance

## Comparison to Other Frameworks

Unlike Cobra (Go) or Click (Python), zshctl:
- Runs in the shell process (no exec overhead)
- Has zero dependencies beyond Zsh
- Provides shell-native features (parameter expansion, arrays, etc.)
- Generates optimal parsing code rather than runtime parsing