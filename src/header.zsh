zmodload zsh/parameter

function {
    typeset -xgA ZSHCTL_CONFIGURATION
    typeset -xg  ZSHCTL_PRIORS=()
    typeset -xg  ZSHCTL_INCLUDE=()
}
