#!/zshctl/bin/zshctl

function :execute:yum {
    include heredoc
    export GPG_TTY=$(tty)
    typeset version
    version=$(compiled/$conf[program]/bin/$conf[program] version) ||
        abend 'fatal: cannot get version'
    [[ -z $version ]] && abend 'no version'
    mkdir -p /html
    find previous/yum
    #exit 1
    #if [[ -d previous/yum ]]; then
    #    mv previous/yum /html/yum
    #else
    #    mkdir /html/yum
    #fi
    gpg --import /run/secrets/gpg
    gpg --list-secret-keys --keyid-format=long
    rpmdev-setuptree
    mkdir $conf[program]-$version
    ls /work/compiled
    typeset shares=() datarootdir='%{_datarootdir}'
    pushd $conf[program]-$version
    mkdir bin
    install -m 755 /work/compiled/$conf[program]/bin/$conf[program] bin/$conf[program]
    cp -r /work/compiled/$conf[program]/share .
    shares=( "${(f)$(find share -type f)}" )
    shares=( "${(@)shares//share/$datarootdir}" )
    shares+=( '' )
    popd
    tar -czvf ~/rpmbuild/SOURCES/$conf[program]-$version.tar.gz $conf[program]-$version
    # create an RPM spec
    heredoc -q <<'    EOF' | tee $conf[program].spec
    Name:       $conf[program]
    Version:    $version
    Release:    1
    Summary:    $conf[description]
    License:    $conf[license]
    BuildArch:  noarch

    Source0:    %{name}-%{version}.tar.gz

    Requires:   $conf[yum.dependencies]

    %description
    $conf[description]

    %global debug_package %{nil}

    %prep
    # we have no source, so nothing here
    %setup -q

    %build

    %install
    rm -rf \$RPM_BUILD_ROOT
    mkdir -p \$RPM_BUILD_ROOT/%{_bindir} \$RPM_BUILD_ROOT/%{_datarootdir}
    install -m 755 bin/$conf[program] \$RPM_BUILD_ROOT/%{_bindir}/$conf[program]
    cp -R share/$conf[program] \$RPM_BUILD_ROOT/%{_datarootdir}/$conf[program]

    %files
    %{_bindir}/$conf[program]
    ${(F)shares}

    %changelog
    # let's skip this for now
    EOF
    cat $conf[program].spec
    rpmbuild -ba $conf[program].spec || abend '`rpmbuild` failed.'
    heredoc -q <<'    EOF' > ~/.rpmmacros
    %_gpg_path /root/.gnupg
    %_gpg_name $conf[gpg.key.name]
    %_gpg_digest_algo sha256
    EOF
    gpg --list-keys
    # sign
    rpm --addsign /root/rpmbuild/RPMS/noarch/$conf[program]-$version-1.noarch.rpm ||
        abend '`rpm --addsign` failed.'
    gpg --export --armor $conf[gpg.key.name] > public.key
    rpm --import public.key
    rpm -q gpg-pubkey --qf '%{name}-%{version}-%{release} --> %{summary}\n'
    # verify
    rpm -K /root/rpmbuild/RPMS/noarch/$conf[program]-$version-1.noarch.rpm ||
        abend '`rpm -K` failed.'
    # install
    rpm -i /root/rpmbuild/RPMS/noarch/$conf[program]-$version-1.noarch.rpm ||
        abend '`rpm -i` failed.'
    [[ "$(=$conf[program] version)" = $version ]] ||
        abend 'install falled.'
    if [[ -e /work/previous/zero ]]; then
        mkdir -p /html/yum/repo
    else
        mv /work/previous/yum /html/yum
    fi
    cp /root/rpmbuild/RPMS/noarch/$conf[program]-$version-1.noarch.rpm /html/yum/repo
    createrepo /html/yum/repo || abend '`createrepo` failed.'
    rm -f /html/yum/repo/repodata/repomd.xml.asc
    gpg --batch=true --detach-sign --armor /html/yum/repo/repodata/repomd.xml ||
        abend '`gpg --detach-sign` failed.'
}

# vim: ft=zsh:
