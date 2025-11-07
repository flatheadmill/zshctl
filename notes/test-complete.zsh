#!/bin/zsh
# test-complete.zsh

function _test_complete {
  typeset -a numbers descriptions
  numbers=(123 456 789)
  descriptions=("Fix the login bug" "Add dark mode" "Update dependencies")
  compadd -d descriptions -- "${numbers[@]}"
}

compdef _test_complete test-complete

function test-complete {
  print "You selected: $1"
}
