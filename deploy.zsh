# TODO Check that the top commit is `Release 0.0.X` and refuse to push.
(cd ../zshctl.github.io && rm -rf *)
docker cp $(docker create --name tc ghcr.io/flatheadmill/zshctl:v0.0.6):/var/zshctl.github.io ../ && docker rm tc
git -C ../zshctl.github.io add .
git -C ../zshctl.github.io commit -n --amend -m 'Release 0.0.6.'
git -C ../zshctl.github.io push --force origin HEAD
