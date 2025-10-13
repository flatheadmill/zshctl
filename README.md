## MANDOC

We write our help in mandoc and in the most basic mandoc. We use `groff` on
Linux to display our mandoc and we use `mandoc` on OS X.

We follow conventions for mandoc and if you diverge from these conventions you
might want to chat with us let's think about it. It's more than enough for us
to make useful help.

We've hacked mandoc a little bit. First, no `.TH` line. We'll generate that
for you. Secondly, we have a pre-compiler that does two things.

First, if you add the bogus macro `.PG`, it will replace any instance of
`zshctl` on the line with the name of the program. This is so you can reuse
commands between programs and `zshctl` is acting as a stand-in for the
ultimate program name.

Second, for autoloading, we have the ability to auto-generate your commands
section. It will be a sorted list of commands that are available according to
the command discovery mechanism, which is still in flux.

## Utilities

### `heredoc`

The `heredoc` function solves the spaces vs tabs problem with multi-line strings in shell scripts. While Zsh's built-in `<<-` heredoc only strips leading tabs, `heredoc` strips common leading spaces, working with how modern editors actually indent.

**Basic usage:**
```zsh
include heredoc

# Assign clean YAML to variable
typeset config
heredoc -v config <<'    EOF'
    apiVersion: v1
    kind: ConfigMap
    data:
      key: value
EOF
# $config now has the YAML without leading spaces
```

**Modes:**
- `heredoc` - Read from stdin, strip indentation, print to stdout
- `heredoc -v varname` - Assign de-indented content to variable
- `heredoc -q` - Quote mode, preserve literally (for templates with `$vars`)
- `heredoc -f format args...` - Use as printf format string

**Real-world examples:**

YAML template for Kubernetes:
```zsh
typeset template
heredoc -v template <<'    EOF'
    apiVersion: isindir.github.com/v1alpha3
    kind: SopsSecret
    metadata: {}
    spec:
      secretTemplates: {}
EOF
```

Git commit message template with quote mode:
```zsh
typeset message
heredoc -q -v message <<'    EOF'
    ### Description
    ${blocks[description]}
    ### Risk Assessment
    ${blocks[risk_assessment]}
EOF
# Variables like ${blocks[description]} are preserved for later expansion
```

JSON configuration:
```zsh
typeset json_config
heredoc -v json_config <<'    EOF'
    {
      "name": "example",
      "settings": {
        "enabled": true,
        "timeout": 30
      }
    }
EOF
```

This allows natural indentation in your code while producing clean output - pragmatic tooling that works with what developers actually type, not what the tabs vs spaces war says they should type.

## Checklist

- [ ] Documentation.
    - [ ] Document completion commands.
    - [ ] Document version.
- [ ] Autoload new commands.
    - [ ] Create a tied search path.
    - [ ] Search search path at startup, use globs or some such to find
    directories, or a file like `commands.zsh`.
    - [ ] Discover commands in `git` repositories.
    - [ ] Create a git clone in `~/.local/var` or similiar.
    - [ ] Compile on `git clone` and `git pull`.
    - [ ] Skip compilation of symlinked commands.
    - [ ] Implement command description MANDOC generation.
- [ ] Autoload functions.
    - [ ] Weakly mimic `autoload`.

## Diary

### Sun Apr  6 09:39:37 AM CDT 2025

Had the idea that the developer could specify which commands they wanted to
include in their application by providing patterns like `zshctl:*`. I'd have
no use for it. It would be a feature. I'd have no use for it because I'd never
want to exclude `version`, nor the `complition`. I don't always need
completion, for things that are purely programmatic, but I don't need
Zsh builtin `getopts` either, so I just don't call it.

Why do this and add code and wait five years and wonder why I added it and
delete it? Thought about alternatives, like saying that the user could just
remove commands from the `COMMANDS` array, but now I'm providing hooks upon
hooks. Oh, well, I suppose the user could do this with an anonymous function,
so I suppose that settles that.

So, you see? You create these features, but it's Zsh and you'll have something
easier and more obvious if you just pursue the path that smiplifies the core
complexities we're attempting to add to the program.

### Sat Apr  5 12:04:47 PM CDT 2025

Seeing that for local commands we can't quite have something as simple as
having a `./deltactl` directory in a reposiory unless we really want to link
it hard. Oh, well, I suppose we could link all of the individual command
directories, but then we can't extend and existing command without a lot of
thinking about linking.

Easier to have a search path. So a directory structure. If there is a
`command.zsh` then we run that. Now, if we want to go by what we see in the
directory structure, we can link that way, or we can have a configuration file
that is named something like `link-as` and in it we can have `my-project` or
similar, and we can soft link to that directory, but with a different name.

Acceptable.

Loading a library, we be able to get the function name, probably, but probably
not. Not when we are in a nested function, so then we have to go up the stack,
but we would know definitively if we hit a command because we'll have our
command hash.

Or when we source the command and execute it, we update the include path,
which is even easier, isn't it? And we can do it for each command.

### Sat Apr  5 11:40:47 AM CDT 2025

Appears that we explicitly load libraries and automatically load commands.

### Sat Apr  5 09:24:24 AM CDT 2025

Considering autoloading. Compiled Zsh is opportunistic. The source is supposed
to live next the compiled Zsh and it is supposed to be recompiled as needed.
The source path is still reported from `functions_source` when the compiled
Zsh is used. This means we can stick with using `awk` to fetch our MANDOC and
we can easily add additional MANDOC for a description to include in options.

Occurs to me that, we can either symlink to your checkout of the project, or
we can clone the project for you, then symlink to that, so we can have an
`asdf` like extensibility mechanism. In fact, we can prompt you to ask, if
you're in a repo, if you want to link here, or cache a copy.

Could be an extensible dependency installer, then. We're already keeping a
database. Let's make sure that we've correctly white-labeled and that we
create a database for your application, not for `zshctl` in general.

Do you maintain a search path? Or do you have a local path? Search path with
strict rules, I suppose.

We can go ahead and add libraries while you're at it. This is going to make it
easier for someone to pick and choose what they include, and make us feel
better about fiddling with new libraries. We will end up duplicating them on
disk. We might have `block.zsh` for `alfactl` in its search path and another
`block.zsh` in for `bravoctl` in its search path. This bothers me not at all.
If it bothers me later on, try not to let it bother you, me.

Now that we have shebangable programs, we may as well have a go at
autoloading. Make it like `autoload` but let's not delve too deep into
`autoload`. We can learn more about it as we work on our dotfiles. We'll come
back to it when we're ready to benchmark `zshctl` performance.

Two extensions might want to include the same library but at different
versions. We can make this a downstream problem, or else we have to think of a
way to autoload the correct version for a command. Probably the latter. Then
we have a rule that if you go down a command path, you're building a
particular version of a program, so if you want to call another one of your
commands, you should fork a new process and have it do it's resolution.

Note that if you have `charliectl` and you wanto make `zshctl` properties
visible you can just copy it, and maybe then it's a `zshctl` property to know
which one to use?

### Fri Apr  4 12:28:27 AM CDT 2025

Considering how we might have autoloaded extensions to applications, not to
`zshctl` itself, but to a `zshctl` program.

Imagine you have `acmectl`, the utility for managing resources as Acme, Inc.
and you want to have special functions for your `frobinate` repository.

In the repo there could be an `./acmectl` directory with a `frobinate`
file in it, or perhaps a `./acmectl/frobinate/reticuate`,
`./acmectl/frobinate/splines`, etc. We can use directory traversal to list
these options.

We don't want to have relative paths in a search path, that's dangerous.
Considered ad hoc search path manipulation, also dangerious because it would
just end up in your shell history ready to get fired at the wrong time.

Instead, you could symlink it into your path, and your path could then be very
short. It would get linked to the first entry in your path. We can also take
the opportunity to compile the functions and put them in a single package.

A word on packaging. How do you include all the helpers? Separate functions
for each helper? After some consideration, the following seems best.

Found in `notes/packaged.zsh`.

```
function packaged {
    function _packaged_helper {
        print hello, $1
    }
    function packaged {
        _packaged_helper "$@"
    }
    packaged "$@"
}

function {
    packaged world
}
```

Leaning ever harder toward keeping this out of `autoload` and leaving that for
Zsh alone, using a `zshctl` based autoloading mechanism that has features like
the ones described.

Regarding white labeling. That's over now. We're going to instead work with
the shebang line a little more. Obviously, we're considering autoloading and
compiling.

### Thu Apr  3 05:41:38 PM CDT 2025

Shebang lines are recursive, aren't they? That would provide a lot of
structure to work with.

Earlier I was thinking about how one might use `autoload`. `autoload` is a
simple beast, however. You could as easily implement your own `autoload` where
the colons in the function name map to relative file paths in a search path.

You'd need to either be in for a penny, in for a pound, and load an entire
subcommand as needed, or else you could have a structure with a directory name
for the command, but a file with a funny character in it, like `@` or perhaps
you use the `.zsh` extension, oh, yeah, `.` is pretty funny isn't it?
Something like `function.zsh`.

Using the `functions_sources` array, we could always find the mandoc.

But, how to discover it with tab completion? Well, you could now add two
separate sections to the mandoc. A mandoc section and a description section.

Now you can pluck the short desecription. You can create the `OPTIONS` section
of the mandoc programmatically.

How to insert it? With a bogus macro. `.BG` for bogus, I suppose, and have...

```
.SH OPTIONS
.BG options
```

Which could be extended for the program name substitution, or not.

Note too that you can compile Zsh to `*.zwc` files which will load faster, but
we might lose the pointer to the source directory. Suppose we could make a
note of that as we source the file, we're writing an autoloader after all.

### Wed Apr  2 08:54:19 AM CDT 2025

Could just make the user add any additional commands they want.
Also, give them a formula for invoking their own shebang line.
Then compiling is simply appending before the exit split and at the bottom of
the file.

Could the convention be that their man function is named for the file?
And could we have a covention that instead of `blurdyctl:` it's something like
`command:`? I'm going to have to ask Jordan.

```
commands 'blurdyctl:*' 'zshctl:*'
```

### Wed Apr  2 12:20:15 AM CDT 2025

We can change delegate to use a map, it can include both `zshctl:` and `user:`
command, searching for them and adding to the map without the prefix. The
value of the map will include the source file to find the usage, and the
original name, also to fine the usage.

Thoughts like that suggest a way to perform white labeling, but we have
already decided against white-labeling. It's probably not a good idea and it
really doesn't make sense to have two programs with identitcal names.

Instead of white-labeling, you can install your program with an installer that
places `zshctl` in a /usr/libexec/ and make your shebang line use that program
directly. We can add other programs as needed.

Need to register `zshctl.sh` and `zshctl.com`.

We can have a curl installer `sh -c "$(curl -L zshctl.sh)"`. Everything can be
sored in GitHub. We can use `flatheadmill.github.io/zshctl` for APT, yum, apk
and aur. Gentoo and Homebrew can pull their tarballs from elsewhere, so we can
pull them from GitHub downloads. There are limits on downloads and such, but
we are not going to reach them, because this will never gain traction. We are
not going to hit the repository limits any time soon. I only release things
very rarely, and when that happens, all we're doing is storing zipped archive
files. We can always squash and force push to keep the size minimal.

Homebew and ebuild can use a `homebrew` and `ebuild` branch, so Homebrew will
set up quickly. For apt and apk, which will be early, we need to create the
github pages website.

To build we use Docker to get all the different operating system versions. It
is a no-arch build so it can be run on any architecture. We clone the
repository in the build, I suppose, rather than mounting it, and we design it
so that it only really builds releases.

We can see if we can use GitHub pages to host our root domain. No, we host on
S3 or GCS and probably GCS because there's a free-tier.

Need to make some decisions about required commands, like `completion`. Are
they optional or are they conventional. Conventional, I assume. Which means we
also have to have conventions, or we could have conventions for `version` and
`version --long`. If we want to disable these commands, we can deleted them
from the `COMMANDS` array in our application.

Okay, we can white-label. Apparently, I can trace back a function to its
source now, so we can have a compile that keeps a global list of prefixes to
farm for function names. This would be a shorter path to getting the existing
applications out because I don't have to develop a build for `zshctl`.

Note that another reason we cannot universally intersperse arguments is
because we need to detect a shebang line.
