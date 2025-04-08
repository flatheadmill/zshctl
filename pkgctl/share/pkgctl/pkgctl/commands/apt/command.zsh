#!/zshctl/bin/zshctl

function do_hash {
    HASH_NAME=$1
    HASH_CMD=$2
    echo "${HASH_NAME}:"
    for f in $(find -type f); do
        f=$(echo $f | cut -c3-) # remove ./ prefix
        if [ "$f" = "Release" ]; then
            continue
        fi
        echo " $(${HASH_CMD} ${f}  | cut -d" " -f1) $(wc -c $f)"
    done
}

function generate_release {
    # TODO Example Repository?
    heredoc -f "$(date -Ru)" << '    EOF'
        Origin: Example Repository
        Label: Example
        Suite: stable
        Codename: stable
        Version: 1.0
        Architectures: all
        Components: main
        Description: An example software repository
        Date: %s
    EOF
    do_hash "MD5Sum" "md5sum"
    do_hash "SHA1" "sha1sum"
    do_hash "SHA256" "sha256sum"
}

function execute:apt {
    typeset version
    version=$(zsh compiled/$conf[program]/bin/$conf[program] version) ||
        abend 'fatal: cannot get version'
    typeset stem=$conf[program]_${version}_all
    mkdir -p deb/$stem/DEBIAN
    {
        heredoc -q > deb/$stem/DEBIAN/control
    } <<'    EOF'
        Package: $conf[program]
        Version: $version
        Architecture: all
        Maintainer: $conf[user.name] <$conf[user.email]>
        Description: $conf[description]
        Depends: $conf[apt.dependencies]
    EOF
    mkdir -p deb/$stem/usr/bin
    install -m 755 compiled/$conf[program] deb/$stem/usr/bin/$conf[program]
    dpkg-deb --build --root-owner-group deb/$stem
    # get current repository
    mkdir /html
    if [[ ! -e /work/previous/zero ]]; then
        mv /work/previous/apt/ /html/apt/
    fi
    mkdir -p /html/apt/dists/stable/main/binary-all/
    mkdir -p /html/apt/pool/main/
    cp deb/$stem.deb /html/apt/pool/main/
    pushd /html/apt
    dpkg-scanpackages --multiversion --arch all pool/ > dists/stable/main/binary-all/Packages
    popd
    cat /html/apt/dists/stable/main/binary-all/Packages |
        gzip -9 > /html/apt/dists/stable/main/binary-all/Packages.gz
    cat /html/apt/dists/stable/main/binary-all/Packages
    mkdir -p /html/apt/dists/stable
    pushd /html/apt/dists/stable
    generate_release > Release
    popd
    gpg --import /run/secrets/gpg
    gpg --list-secret-keys --keyid-format=long
    cat /html/apt/dists/stable/Release | gpg --default-key 'Package Signing' -abs > /html/apt/dists/stable/Release.gpg ||
        abend 'unable to sign'
    cat /html/apt/dists/stable/Release | gpg --default-key 'Package Signing' -abs --clearsign > /html/apt/dists/stable/InRelease ||
        abend 'unable to clearsign'

    mkdir -p /html/apt/doc
    gpg --armor --export 'Package Signing' > /html/apt/doc/apt-key.gpg
}

# vim: ft=zsh:
