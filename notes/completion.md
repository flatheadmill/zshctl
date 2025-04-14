
Orientation on Zsh completions.

* [A Guide to the Zsh Completion with Examples](https://thevaluable.dev/zsh-completion-guide-examples/) &mdash; Focuses just on customization with `zstyle`. Does not describe how to write new completions. References an earlier post called [Configuring Zsh Without Dependencies](https://thevaluable.dev/zsh-install-configure-mouseless/) and shares an [example configuration](https://github.com/Phantas0s/.dotfiles/blob/master/zsh/completion.zsh) and the [Pretzo completion configuration](https://github.com/sorin-ionescu/prezto/blob/master/modules/completion/init.zsh). Drew my attention to Zsh [visual effects](https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html#Visual-effects).
* [zsh-completions-howto.org](https://github.com/zsh-users/zsh-completions/blob/master/zsh-completions-howto.org) &mdash; An attempt at general documentation on how to write completions using the new completion system. Documents the functions that you'll see in completion code like `_arguments` and `_describe`. Other resources include a post on how to use [`_arguments`](https://wikimatze.de/writing-zsh-completion-for-padrino/) and a [slightly more complicated](https://web.archive.org/web/20190411104837/http://www.linux-mag.com/id/1106/) post on the `_arguments` function.
* [Completion Widgets](https://web.archive.org/web/20190411104837/http://www.linux-mag.com/id/1106/) &mdash; The documentation on the underlying completion builtins. Dense and hard to follow.
* [Completion System](https://web.archive.org/web/20190411104837/http://www.linux-mag.com/id/1106/) &mdash; The documentation on the new completion system. Dense and hard to follow.

The completion system is implemented in Zsh and built on top of [Zsh Line Editor](https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html) (ZLE) features and Zsh builtins. It is more advanced than Bash because of ZLE. Bash uses `readline` to display and edit at its prompt.

`zstyle` is not part of the completion system. It is a function used by the completion system. It is defined in the module `zsh/zutil`. Read more about it in `man zshmodules` and review [this gist of examples](https://gist.github.com/mattmc3/449430b6654aaab0ba7160e8efe8291b). `zstyle` is used to look up customizations of the Zsh completion system.

The Completion System is built on top of the Completion Widgets. `compadd` is part of the Completion System, a primitive. `_arguments` and `_describe` are part of the Completion System.

You are going to want to clone the source of [zsh-completions](https://github.com/zsh-users/zsh-completions/tree/master) and [zsh](https://github.com/zsh-users/zsh) itself for go-bys. The completions in Zsh are actively maintained and the completions for `git`, for example, are [better than](https://lore.kernel.org/git/mrn75pj663u6ikkwfnoq6c342l7w5plfeju4ji7norsmlzx4jn@3se3fmuqes4p/T/) the ones created by the `git` maintainers. You can find them in the `Completions` directory.

The essence of the completion system is using the function `_arguments` to parse the arguments to a line in the midst of completion. The arguments to `_arguments` compose a domain-specific language for parsing the arguments in the line to complete. `_arguments` may resolve the completion itself using it's domain-specific language, or it may set a `state` variable according to its domain-specific language to indicate how far it got. You can then take over with `case` statements.

As noted, `zstyle` comes in to give the user the ability to augment these completions with formatting, priorities, etc.

For `zshctl` we mimicked the completion of the Go Cobra library. We invoke the `zshctl` program to get a list of completions that we parse and use that to populate the completions. In Zsh we use the much simpler `_describe` instead of `_arguments`. We do this because we don't want to write completions twice, once for Zsh and once for Bash, but we can do so much more with Zsh than with Bash. As noted above, Zsh has the ZLE while bash is merely `readline`.

An so, I've solved for some goals in Zsh that I have yet to solve for in Bash. Below are some tasks.

* [Display progress indication while custom ZSH completer is running](https://stackoverflow.com/questions/42412457/display-progress-indication-while-custom-zsh-completer-is-running) &mdash; The 1Password completions are especially slow.
* Extending completions for pluggable subcommands &mdash; A very good answer in [How to add custom git command to Zsh completion?](https://stackoverflow.com/questions/38725102/how-to-add-custom-git-command-to-zsh-completion) and a [bad](https://unix.stackexchange.com/a/501111) answer that referenced [function patching](https://unix.stackexchange.com/a/450133). Function patching is interesting.
* [Completion when program has sub-commands](https://stackoverflow.com/questions/9000698/completion-when-program-has-sub-commands) &mdash; Not anything I was looking for directly, but it did link to a good article on completion with sub-commands called [Writing zsh completions for CLIs with subcommands](https://www.dolthub.com/blog/2021-11-15-zsh-completions-with-subcommands/).

Definitions of Zsh completion functions [`compadd`](https://github.com/zsh-users/zsh/blob/master/Completion/Zsh/Command/_compadd) is a primitive of the completion system, [`_main_complete`](https://github.com/zsh-users/zsh/blob/master/Completion/Base/Core/_main_complete) is the entry point for the new completion system, [`_describe`](https://github.com/zsh-users/zsh/blob/master/Completion/Base/Utility/_describe) is the basic way of displaying completions, [`_arguments`](https://github.com/zsh-users/zsh/blob/master/Completion/Base/Utility/_arguments) is an argument parsing way to display completions or select a method to find completion values, and [`_message`](https://github.com/zsh-users/zsh/blob/master/Completion/Base/Core/_message) will display an error message.

Bash completions are limited and replicating a progress indicator or a warning message is probably going to be a kludge in Bash.k
