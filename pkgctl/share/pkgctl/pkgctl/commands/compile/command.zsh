function execute:compile {
    typeset version=$NEXT_VERSION
    # Get the seconds since the epoch of the commit.
    date=$(git -C /zshctl show --no-patch --format=%ct)
    # Copy source.
    cp -r /zshctl $conf[program]
    rm -rf $conf[program]/.git
    # Compile `zshctl`.
    {
        heredoc -f ${(qqq)NEXT_VERSION} $date > $conf[program]/share/$conf[program]/release.zsh
    } <<'    EOF'
        zshctl[version]=%s
        zshctl[release_date]=%d
    EOF
    # Check version.
    $conf[program]/bin/$conf[program] version
    # Create a tarball containing only `zshctl`.
    tar -C $conf[program] -czvf /work/$conf[program]-$version.tar.gz bin/zshctl share
    # Export the public key of the GPG signing key.
    mkdir -p /work/html/keys
    gpg --import /run/secrets/gpg
    gpg --list-secret-keys --keyid-format=long
    openssl rsa -in /run/secrets/rsa -pubout -out /work/html/keys/$conf[apk.key.name].rsa.pub
    gpg --armor --export 'Package Signing' > /work/html/keys/gpg
}
