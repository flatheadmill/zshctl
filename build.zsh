typeset -A version=( "${(@QA)${(z)$(
    jq -r '[ "previous", .previous, "next", .next ] | @sh' < versions.json
)}}" )

docker build \
    --platform linux/amd64 \
    --build-arg PREVIOUS_VERSION=$version[previous] \
    --build-arg NEXT_VERSION=$version[next] \
    --secret id=rsa,src=$HOME/secrets/flatheadmill/rsa \
    --secret id=gpg,src=$HOME/secrets/flatheadmill/gpg \
    --progress plain -t ghcr.io/flatheadmill/zshctl:v$version[next] .
