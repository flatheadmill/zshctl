#!/zshctl/bin/zshctl

function :execute:aur {
    include heredoc
    typeset version
    version=$(zsh compiled/$conf[program]/bin/$conf[program] version) ||
        abend 'fatal: cannot get version'
    mkdir /gpg/build
    export GNUPG_HOME=/gpg/build
    chmod 700 /gpg/build
    gpg --import /run/secrets/gpg
    gpg --list-secret-keys --keyid-format=long
    heredoc -q <<'    EOF' > PKGBUILD
    # Maintainer: $conf[user.name] <$conf[user.email]>
    pkgname=$conf[program]
    pkgver=$version
    pkgrel=1
    epoch=
    pkgdesc=""
    arch=("any")
    url=""
    license=(${(qq)conf[license]})
    groups=()
    depends=( $conf[aur.dependencies] )
    makedepends=()
    checkdepends=()
    optdepends=()
    provides=()
    conflicts=()
    replaces=()
    backup=()
    options=()
    install=
    changelog=
    source=("$conf[program].tar.gz")
    noextract=()
    md5sums=()
    validpgpkeys=()

    prepare() {
        true
    }

    build() {
        true
    }

    check() {
        true
    }

    package() {
        mkdir -p "\$pkgdir/usr/bin"
        cp bin/$conf[program] "\$pkgdir/usr/bin"
        cp -r share "\$pkgdir/usr/share"
    }

    md5sums=('SKIP')
    EOF
    cat PKGBUILD
    cp compiled/$conf[program]-$version.tar.gz $conf[program].tar.gz
    makepkg --sign || abend '`makepkg` failed.'
    mkdir -p /html/aur
    if [[ -d /work/previous/aur ]]; then
        cp /work/previous/aur/*.pkg.tar.* /html/aur/
    fi
    mv $conf[program]-$version-1-any.pkg.tar.* /html/aur
    repo-add --sign /html/aur/$conf[program].db.tar.gz /html/aur/*.pkg.tar.zst ||
        abend '`repo-add --sign` failed.'
}

# vim: ft=zsh:
