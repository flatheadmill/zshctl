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

## Diary

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

We can change delegate to use a map, it can include both `zshctl:` and `user:` command, searching for them and adding to the map without the prefix. The value of the map will include the source file to find the usage, and the original name, also to fine the usage.

Thoughts like that suggest a way to perform white labeling, but we have already decided against white-labeling. It's probably not a good idea and it really doesn't make sense to have two programs with identitcal names.

Instead of white-labeling, you can install your program with an installer that places `zshctl` in a /usr/libexec/ and make your shebang line use that program directly. We can add other programs as needed.

Need to register `zshctl.sh` and `zshctl.com`.

We can have a curl installer `sh -c "$(curl -L zshctl.sh)"`. Everything can be sored in GitHub. We can use `flatheadmill.github.io/zshctl` for APT, yum, apk and aur. Gentoo and Homebrew can pull their tarballs from elsewhere, so we can pull them from GitHub downloads. There are limits on downloads and such, but we are not going to reach them, because this will never gain traction. We are not going to hit the repository limits any time soon. I only release things very rarely, and when that happens, all we're doing is storing zipped archive files. We can always squash and force push to keep the size minimal.

Homebew and ebuild can use a `homebrew` and `ebuild` branch, so Homebrew will set up quickly. For apt and apk, which will be early, we need to create the github pages website.

To build we use Docker to get all the different operating system versions. It is a no-arch build so it can be run on any architecture. We clone the repository in the build, I suppose, rather than mounting it, and we design it so that it only really builds releases.

We can see if we can use GitHub pages to host our root domain. No, we host on S3 or GCS and probably GCS because there's a free-tier.

Need to make some decisions about required commands, like `completion`. Are they optional or are they conventional. Conventional, I assume. Which means we also have to have conventions, or we could have conventions for `version` and `version --long`. If we want to disable these commands, we can deleted them from the `COMMANDS` array in our application.

Okay, we can white-label. Apparently, I can trace back a function to its source now, so we can have a compile that keeps a global list of prefixes to farm for function names. This would be a shorter path to getting the existing applications out because I don't have to develop a build for `zshctl`.

Note that another reason we cannot universally intersperse arguments is because we need to detect a shebang line.
