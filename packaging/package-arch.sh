#!/usr/bin/env bash

repo_file="/var/lib/plapadoo-arch-repo/custom.db.tar.gz"

set -e
shopt -s extglob

mkdir -p packaging/src/keepbooks
cp -R !(packaging) packaging/src/keepbooks
cd packaging
makepkg --noextract
repo-add "$repo_file" ./*.xz
scp "$repo_file" "cremaster:$repo_file"
