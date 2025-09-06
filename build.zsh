docker build \
    --build-arg PREVIOUS_VERSION=0.0.2 \
    --build-arg NEXT_VERSION=0.0.3 \
    --secret id=rsa,src=$HOME/secrets/flatheadmill/rsa \
    --secret id=gpg,src=$HOME/secrets/flatheadmill/gpg \
    --progress plain -t ghcr.io/flatheadmill/zshctl:v0.0.3  .
