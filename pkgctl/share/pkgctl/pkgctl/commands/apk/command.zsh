#!/zshctl/bin/zshctl

function execute:apk {
    typeset version
    version=$(compiled/$conf[program]/bin/$conf[program] version) ||
        abend 'fatal: cannot get version'
    whoami
    mkdir -p ~/.abuild
    mkdir -p /html
    mkdir -p ~/packages
    git config --global user.name $conf[user.name]
    git config --global user.email $conf[user.email]
    git config --global init.defaultBranch main
    mkdir origin.git
    git -C origin.git init
    cp -r compiled/$conf[program] origin.git/$conf[program]
    git -C origin.git add .
    git -C origin.git commit -m 'Sketch.'
    git clone ./origin.git
    cp /run/secrets/rsa ~/.abuild/$conf[apk.key.name].rsa
    openssl rsa -in /run/secrets/rsa -pubout -out ~/.abuild/$conf[apk.key.name].rsa.pub
    {
        heredoc -q | tee ~/.abuild/abuild.conf
    } <<'    EOF'
        PACKAGER_PRIVKEY=$HOME/.abuild/$conf[apk.key.name].rsa
        PACKAGER="$conf[user.name] <$conf[user.email]>"
        MAINTAINER="\$PACKAGER"
        REPODEST=\$HOME/packages
    EOF
    pushd compiled/$conf[program]
    {
        heredoc -q | tee APKBUILD
    } <<'    EOF'
    # Maintainer: $conf[user.name] <$conf[user.email]>
    pkgver=$version
    pkgname=$conf[program]
    pkgrel=0
    pkgdesc=${(qqq)conf[description]}
    url=$conf[url.home]
    arch="x86_64"
    license=$conf[license]
    depends=${(qqq)conf[apk.dependencies]}
    depends_dev=""
    #makedepends=""
    install=""
    subpackages=""
    source=""
    builddir="\$srcdir/\$pkgname-\$pkgver"

    prepare() {
        default_prepare
    }

    build() {
        true
    }

    check() {
        true
    }

    package() {
        pwd
        ls -la
        mkdir -p "\$pkgdir/usr/bin"
        cp bin/$conf[program] "\$pkgdir/usr/bin"
        cp -r share "\$pkgdir/usr/share"
    }
    EOF
    abuild checksum || abend '`abuild checksum` failed'
    abuild -r || abend '`abuild -r` failed'
    # TODO Can I make this a no-arch package?
    mkdir -p /html/apk/x86_64
    if [[ ! -e previous/zero ]]; then
        cp /work/previous/apk/x86_64/*.apk /html/apk/x86_64
    fi
    find /home/build/packages
    cp /home/build/packages/compiled/x86_64/$conf[program]-$version-r0.apk /html/apk/x86_64
    pushd /html/apk/x86_64
    apk index --no-warnings -vU -o APKINDEX.tar.gz *.apk
    popd
    abuild-sign -k ~/.abuild/$conf[apk.key.name].rsa /html/apk/x86_64/APKINDEX.tar.gz
}

# vim: ft=zsh:
