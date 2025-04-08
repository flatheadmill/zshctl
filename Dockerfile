ARG PREVIOUS_VERSION

FROM ghcr.io/flatheadmill/zshctl:v${PREVIOUS_VERSION} AS fetched

FROM fetched AS previous

COPY --from=fetched /var/zshctl.github.io/ /html/

FROM alpine AS compiled

ARG NEXT_VERSION
RUN apk update && apk add zsh git gpg gpg-agent
COPY ./ /zshctl/
WORKDIR /work
RUN --mount=type=secret,id=gpg --mount=type=tmpfs,dst=/root/.gnupg /zshctl/pkgctl/bin/pkgctl compile
RUN zsh -c '[[ ! -d /root/.gnupg ]]'

FROM alpine AS brew

RUN apk update && apk add zsh wget git ruby
COPY --from=previous /html/ /work/previous/
COPY --from=compiled /work/ /work/compiled/
COPY ./ /zshctl/
WORKDIR /work
RUN /zshctl/pkgctl/bin/pkgctl brew

FROM ubuntu:noble AS apt

RUN apt-get update && apt-get install -y make dpkg-dev git wget zsh
COPY --from=previous /html/ /work/previous/
COPY --from=compiled /work/ /work/compiled/
COPY ./ /zshctl/
WORKDIR /work
RUN --mount=type=secret,id=gpg --mount=type=tmpfs,dst=/root/.gnupg /zshctl/pkgctl/bin/pkgctl apt
RUN zsh -c '[[ ! -d /root/.gnupg ]]'

FROM alpine AS apk

RUN apk --no-progress update && apk --no-progress upgrade && apk --no-progress add sudo alpine-sdk zsh && adduser -u 1983 -D -h /home/build -s /bin/false build && addgroup build abuild && mkdir /work /html && chown build:build /work /html
COPY --chown=1983:1983 --from=compiled /work/ /work/compiled/
COPY --chown=1983:1983 --from=previous /html/ /work/previous/
COPY --chown=1983:1983 ./ /zshctl/
WORKDIR /work
# Separate invocation to copy the public key to the operating system's `/etc` as root.
RUN --mount=type=secret,id=rsa openssl rsa -in /run/secrets/rsa -pubout -out /etc/apk/keys/alan@prettyrobots.com-67eee297.rsa.pub
USER build
RUN --mount=type=secret,id=rsa,uid=1983 --mount=type=tmpfs,dst=/home/build/.abuild /zshctl/pkgctl/bin/pkgctl apk
RUN zsh -c '[[ ! -d /home/build/.abuild ]]'

FROM fedora AS yum

RUN dnf install -y git wget gcc rpm-build rpm-devel rpmlint make python bash coreutils diffutils patch rpmdevtools zsh groff which glibc-common rpm-sign createrepo less groff-base
COPY --from=previous /html/ /work/previous/
COPY --from=compiled /work/ /work/compiled/
COPY ./ /zshctl/
WORKDIR /work

RUN --mount=type=secret,id=gpg --mount=type=tmpfs,dst=/root/.gnupg /zshctl/pkgctl/bin/pkgctl yum
RUN zsh -c '[[ ! -d /root/.gnupg ]]'

FROM archlinux AS aur

RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman --noconfirm -Sy archlinux-keyring && \
    pacman --noconfirm -S base-devel zsh wget jo jq && \
    useradd -u 1983 -d /home/build -s /bin/false build && usermod -L build && \
    mkdir -p /work /html /home/build && chown build:build /work /html /home/build
COPY --chown=1983 --from=compiled /work/ /work/compiled/
RUN pacman-key --add /work/compiled/gpg && pacman-key --lsign-key 8262C8D6D0959C6F
COPY --chown=1983 --from=previous /html/ /work/previous/
COPY ./ /zshctl/
WORKDIR /work
USER build
RUN --mount=type=secret,id=gpg,uid=1983 --mount=type=tmpfs,dst=/gpg /zshctl/pkgctl/bin/pkgctl aur
RUN zsh -c '[[ ! -d /gpg ]]'

FROM gentoo/portage:latest AS portage

FROM gentoo/stage3:latest AS gentoo

RUN emaint --all sync && FEATURES="-ipc-sandbox -mount-sandbox -network-sandbox -pid-sandbox" emerge app-eselect/eselect-repository emerge dev-vcs/git zsh
COPY --from=compiled /work/ /work/compiled/
COPY --from=previous /html/ /work/previous/
COPY ./ /zshctl/
WORKDIR /work
RUN --mount=type=secret,id=gpg --mount=type=tmpfs,dst=/root/.gnupg /zshctl/pkgctl/bin/pkgctl emerge
RUN zsh -c '[[ ! -d /root/.gnupg ]]'

FROM alpine AS index

COPY --from=brew /html/ /html/
COPY --from=apt /html/ /html/
COPY --from=apk --chown=0:0 /html/ /html/
COPY --from=yum /html/ /html/
COPY --from=aur --chown=0:0 /html/ /html/
COPY --from=gentoo /html/ /html/

RUN du -sh /html/

FROM alpine

COPY --from=index /html/ /var/zshctl.github.io/
