#!/bin/sh

cat <<'EOF' > /dev/null

                           Welcome to `zshctl`.

This is a secret message that will not be emitted when the script is run. How
fastidious of you to view the source before running a `curl | bash`.

But, don't pipe, please. Run this script like so...

    sh -c "$(curl -sL https://zshctl.sh/zshctl.sh)"

Or with `wget` on a bare-bones Ubuntu.

    sh -c "$(wget -qO - https://zshctl.sh/zshctl.sh)"

This script is an installer selector. It will...

    1) determine what system you are on,
    2) tell you about the install script for your system,
    3) show you the install script for your system,
    4) ask you if you want to run the install script and,
    5) run the install script if you agree.

This is cross-platform, lowest common denominator shell. The selected installer
will be platform specific. The platform specific installer is very simple so if
you'd like you can just run those commands yourself.

You can continue reading to review the script.

EOF

# 1) determine what system you are on,

# OS X aliases `more` to `less`, silly, so if we have a `less` we'll use it
# instead of `more`, but with options that will make it more like `more`.
pager() {
#   if which less > /dev/null 2>&1; then
#       less -XE
#    elif more --help | grep exit-on-eof > /dev/null; then
    if more --help 2>&1 | grep exit-on-eof > /dev/null; then
       more -e
    else
        more
    fi
}

# determine the HTTP client
if type curl >/dev/null 2>&1; then
    ua=curl
elif type wget >/dev/null 2>&1; then
    ua=wget
else
    echo 'neither `curl` nor `wget` is installed, please install one or the other' 1>&2
    exit 1
fi

# select an intaller based on platform, ensure that the same HTTP agent used to
# view the script is used to execute it.
installer='Unknown-unknown'
case "$(uname)" in
    Darwin )
        installer='Darwin-brew.zsh'
        ua=/usr/bin/curl
        ;;
    Linux )
        if [ -e /etc/os-release ]; then
            . /etc/os-release
            case "$ID-$ua" in
                alpine-* )
                    installer='Linux-alpine.sh'
                    ;;
                arch-* )
                    installer='Linux-arch.bash'
                    ua=/usr/bin/curl
                    ;;
                debian-curl )
                    installer='Linux-debian-curl.bash'
                    ua=/usr/bin/curl
                    ;;
                debian-wget )
                    installer='Linux-debian-wget.bash'
                    ua=/usr/bin/wget
                    ;;
                fedora-* )
                    installer='Linux-fedora.bash'
                    ua=/usr/bin/curl
                    ;;
                gentoo-* )
                    installer='Linux-gentoo.bash'
                    ua=/usr/bin/wget
                    ;;
                pop-* | ubuntu-* )
                    installer='Linux-ubuntu.bash'
                    ua=/usr/bin/wget
                    ;;
            esac
        fi
        ;;
esac

# 2) tell you about the install script for your system,
# 3) show you the install script for your system,

# show installer description and installer source to user
case "$ua-$installer" in
    *curl-Unknown-unknown )
        $ua -sL "https://zshctl.sh/install/$installer.txt" | pager
        ;;
    *wget-Unknown-unknown )
        $ua -qO - "https://zshctl.sh/install/$installer.txt" | pager
        ;;
    *curl* )
        {
            $ua -sL "https://zshctl.sh/install/$installer.txt"
            echo ''
            echo --------------------------------------------------------------------------------
            $ua -sL "https://zshctl.sh/install/$installer"
            echo --------------------------------------------------------------------------------
            echo ''
        } | pager
        ;;
    *wget* )
        (
            $ua -qO - "https://zshctl.sh/install/$installer.txt"
            echo ''
            echo --------------------------------------------------------------------------------
            $ua -qO - "https://zshctl.sh/install/$installer"
            echo --------------------------------------------------------------------------------
            echo ''
        ) | pager
        ;;
esac

# if we don't know what platform we're on, then there's nothing more to do
if [ "$installer" = Unknown-* ]; then
    exit
fi

# 4) ask you if you want to run the install script and,

# approval prompt
echo 'Do you want to run the `zshctl` installer?'
echo 'Only "yes" will be accepted to approve.'
echo ''
printf '    Enter a value: '
read -r yn
echo ''

# without approval there is nothing more to do
if [ x"$yn" != xyes ]; then
    exit
fi

# 5) run the install script if you agree.

# run the installer
case "$installer" in
    Darwin-brew.zsh )
        /bin/zsh -c "$(/usr/bin/curl -sL https://zshctl.sh/install/Darwin-brew.zsh)"
        ;;
    Linux-alpine.sh )
        /usr/bin/sudo /bin/sh -c "$(/usr/bin/wget -qO - https://zshctl.sh/install/Linux-alpine.sh)"
        ;;
    Linux-arch.bash )
        /usr/bin/sudo /bin/bash -c "$(/usr/bin/curl -sL https://zshctl.sh/install/Linux-arch.bash)"
        ;;
    Linux-debian-curl.bash )
        /usr/bin/sudo /bin/bash -c "$(/usr/bin/curl -sL https://zshctl.sh/install/Linux-debian-curl.bash)"
        ;;
    Linux-debian-wget.bash )
        /usr/bin/sudo /bin/bash -c "$(/usr/bin/wget -qO - https://zshctl.sh/install/Linux-debian-wget.bash)"
        ;;
    Linux-fedora.bash )
        /usr/bin/sudo /bin/bash -c "$(/usr/bin/curl -sL https://zshctl.sh/install/Linux-fedora.bash)"
        ;;
    Linux-gentoo.bash )
        /usr/bin/sudo /bin/bash -c "$(/usr/bin/wget -qO - https://zshctl.sh/install/Linux-gentoo.bash)"
        ;;
    Linux-ubuntu.bash )
        /usr/bin/sudo /bin/bash -c "$(/usr/bin/wget -qO - https://zshctl.sh/install/Linux-ubuntu.bash)"
        ;;
esac
