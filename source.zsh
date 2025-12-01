sha=$(git rev-parse HEAD)
docker build --progress plain -t ghcr.io/flatheadmill/zshct:src-$sha -f Dockerfile.source --push .
