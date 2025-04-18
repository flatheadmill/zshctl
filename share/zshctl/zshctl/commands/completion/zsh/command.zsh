function execute:completion:zsh {
    sed -e 's/zshctl/'$zshctl[program]'/g' \
        "${functions_source[execute:completion:zsh]:A:h}/complete.zsh"
}
