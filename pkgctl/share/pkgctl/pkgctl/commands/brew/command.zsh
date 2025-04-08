function execute:brew {
    typeset version
    version=$(zsh compiled/$conf[program]/bin/$conf[program] version) ||
        abend 'fatal: cannot get version'
    typeset forumula=${functions_source[execute:brew]:h}/formula.rb
    # Configure `git`.
    git config --global user.email $conf[user.email]
    git config --global user.name $conf[user.name]
    git config --global init.defaultBranch main
    # If we have never been run before, create a new repo and directory
    # structure, otherwise copy over the previous directory structure.
    if [[ -e previous/zero ]]; then
        mkdir brew.git
        git -C brew.git init
        git -C brew.git commit --allow-empty -m 'Initial commit.'
        git -C brew.git log -n 1
        git clone brew.git brew
        mkdir -p /html/downloads
    else
        mv /work/previous/downloads html/downloads
    fi
    # Create a tarball containing the program.
    mv compiled/$conf[program]-$version.tar.gz /html/downloads/
    # Create a `sha256sum` file for the directory repository.
    ( cd /html/downloads && sha256sum *.tar.gz > sha256sum )
    cat /html/downloads/sha256sum
    # TODO Too chatty.
    git -C brew log
    typeset sha256sum
    sha256sum=$(
        awk -v file="$conf[program]-$version.tar.gz" '$2 == file { print $1 }' \
            /html/downloads/sha256sum
    )
    typeset -A ruby
    typeset key value
    conf[url.download]=$conf[url.repo]/downloads/$conf[program]-$version.tar.gz
    for key value in "${(@kv)conf}"; do
        ruby[$key]=$(ruby -e 'puts ARGV[0].dump()' "$value")
    done
    mkdir -p brew/formula
    heredoc -q <<'    EOF' | tee brew/formula/$conf[program].rb
        require "formula"

        class ${(C)conf[program]} < Formula
          desc $ruby[description]
          homepage $ruby[url.home]
          url $ruby[url.download]
          sha256 "SHA256SUM"

          def install
            bin.install $ruby[url.program]
            share.install $ruby[url.program]
          end

          # Homebrew requires tests.
          test do
            assert_match "VERSION", shell_output("#{bin}/$conf[program] version", 2)
          end
        end
    EOF
    exit
    git -C brew add .
    typeset mesage
    printf -v message 'Release `%s`.' $conf[program]-$version
    git -C brew commit -m $message || abend 'cannot `git commit` formula repository'
    git -C brew log -n 1 -p || abend 'cannot log formula repository'
    git -C /html clone --bare /work/brew/ || abend 'cannot clone bare repository'
    git -C /html/brew.git update-server-info || abend 'cannot update server info'
}
