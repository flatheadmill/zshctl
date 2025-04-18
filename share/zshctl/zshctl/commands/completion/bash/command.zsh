function execute:completion:bash {
    sed -e 's/zshctl/'$zshctl[program]'/g' \
        "${functions_source[execute:completion:bash]:A:h}/complete.bash"
}
