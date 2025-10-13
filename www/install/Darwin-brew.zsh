#!/bin/zsh

# must run in zsh.
if [ -z "$ZSH_VERSION" ]; then
    echo 'error: installer must be run with `zsh`, not `bash` or `sh`.' 1>&2
    exit 1
fi

# if no brew, prompt to install it.
if ! whence brew > /dev/null; then
    curl -sL https://zshctl.sh/install/install-Darwin-brew-missing.txt | more

    print -R "Enter a value: "
    read -r yn
    print -R ""

    if [[ "$yn" = yes ]]; then
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # still now brew, give up.
    if ! whence brew > /dev/null; then
        echo 'error: Cannot find Homebrew, OS X installation requires Homebrew.' 1>&2
        exit 1
    fi
fi

# tap and install zshctl.
brew install zshctl/zshctl/zshctl
#brew install zshctl

type zshctl
"$(brew --prefix)/bin/zshctl" version
