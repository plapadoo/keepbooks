#!/usr/bin/env bash

set -e

mkdir -p packaging/src/keepbooks
cp -R ./* packaging/src/keepbooks
cd packaging
makepkg --noextract
repo-add /home/gitlab-runner/repo.db.tar.gz ./*.xz
