#!/zshctl/bin/zshctl

# TODO Ensure that `heredoc` can allow tabs.
function ebuild_conf {
# TODO noarch?
# An `.ebuild` is just a Bash program. It must be indented with tabs and not with spaces.
    heredoc -q <<'    EOF'
        # Copyright 2022 Gentoo Authors
        # Distributed under the terms of the GNU General Public License v2

        EAPI=8

        DESCRIPTION=${(qqq)conf[description]}
        HOMEPAGE=${(qqq)conf[url.home]}
        SRC_URI="${conf[url.repo]}/downloads/zshctl-$version.tar.gz"

        LICENSE=${(qqq)conf[license]}
        SLOT="0"
        KEYWORDS="amd64"

        DEPEND=""
        RDEPEND="\${DEPEND} app-shells/zsh dev-vcs/git sys-apps/groff sys-apps/less"
        BDEPEND=""
        S=\${WORKDIR}

        src_install() {
            dobin bin/$conf[program]
            insinto /usr/share
            doins -r share/$conf[program]
        }
    EOF
}

function :execute:emerge {
    include heredoc
    typeset version
    version=$(compiled/$conf[program]/bin/$conf[program] version) ||
        abend 'fatal: cannot get version'
    export FEATURES="-ipc-sandbox -mount-sandbox -network-sandbox -pid-sandbox"
    gpg --import /run/secrets/gpg
    gpg --list-secret-keys --keyid-format=long
    git config --global user.email 'alan@prettyrobots.com'
    git config --global user.name 'Alan Gutierrez'
    git config --global user.signingkey 8262C8D6D0959C6F
    git config --global commit.gpgsign true
    git config --global init.defaultBranch main
    mkdir -p /etc/portage/repos.conf
    if [[ -e previous/zero ]]; then
        mkdir previous/ebuild.git
        git -C previous/ebuild.git init
        git -C previous/ebuild.git commit --allow-empty -m 'Initial commit.'
        mkdir previous/ebuild.git/metadata
        heredoc <<'        EOF' > previous/ebuild.git/metadata/layout.conf
            masters = gentoo
        EOF
        git -C previous/ebuild.git add .
        git -C previous/ebuild.git commit --allow-empty -m 'Add `layout.conf`.'
        git -C previous/ebuild.git log -n 1
    fi
    heredoc -q <<'    EOF' > /etc/portage/repos.conf/$conf[program].conf
        [$conf[program]]
        location = /work/ebuild
        sync-type = git
        sync-uri = /work/previous/ebuild.git
    EOF
    emaint --repo $conf[program] sync || abend 'cannot run `emaint sync`'
    # TODO Better classification?
    mkdir -p /work/ebuild/app-misc/$conf[program]
    ebuild_conf > /work/ebuild/app-misc/$conf[program]/$conf[program]-$version.ebuild
    cat /work/ebuild/app-misc/$conf[program]/$conf[program]-$version.ebuild
    mkdir -p /var/cache/distfiles/
    cp /work/compiled/$conf[program]-$version.tar.gz /var/cache/distfiles/
    cp /work/compiled/$conf[program]-$version.tar.gz .
    export GPG_TTY=$(tty)
    mkdir -p /work/ebuild/app-misc/$conf[program]
    printf 'DIST %s-%s.tar.gz %s SHA512 %s\n' \
        $conf[program] $version \
        $(wc -c zshctl-$version.tar.gz | cut -d' ' -f1) \
        $(sha512sum zshctl-$version.tar.gz | cut -d' ' -f1) >> /work/ebuild/app-misc/zshctl/Manifest
    ebuild /work/ebuild/app-misc/$conf[program]/$conf[program]-$version.ebuild manifest ||
        abend '`ebuild` failed'
    git -C ebuild add .
    git -C ebuild branch -m main
    typeset message
    printf -v message 'Release `%s` %s.' $conf[program] $version
    git -C ebuild commit -S -m $message
    git -C ebuild log -n 3
    mkdir -p /html
    git -C /html clone --bare /work/ebuild
    git -C /html/ebuild.git update-server-info
}

# vim: ft=zsh:
