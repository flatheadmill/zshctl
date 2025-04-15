zmodload zsh/terminfo

function set_completion_indicator {
  echoti sc # save_cursor
  echoti cup $((LINES - 1)) $((COLUMNS - $#1)) # cursor_position
  echoti setaf $2 # set_foreground (color)
  printf %s $1
  echoti sgr 0 # exit_attribute_mode
  echoti rc # restore_cursor
  #sleep 1
}

completion_indicator_text='(completing)'
completion_indicator_color=3
function display_completion_indicator {
  compprefuncs+=(display_completion_indicator)
  set_completion_indicator $completion_indicator_text $completion_indicator_color
}

function hide_completion_indicator {
  comppostfuncs+=(hide_completion_indicator)
  # The completion code erases the indicator, so there's nothing to do.
}

compprefuncs+=(display_completion_indicator)
comppostfuncs+=(hide_completion_indicator)
