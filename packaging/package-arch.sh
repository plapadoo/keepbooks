#!/usr/bin/env bash

repo_path=/var/lib/plapadoo-arch-repo
repo_file="$repo_path/custom.db.tar.gz"
files_file="$repo_path/custom.files.tar.gz"

set -e
shopt -s extglob

mkdir -p packaging/src/keepbooks
cp -R !(packaging) packaging/src/keepbooks
cd packaging
makepkg --noextract
repo-add "$repo_file" ./*.xz
cp ./*.xz "$repo_path"
scp "$repo_file" "cremaster:$repo_file"
scp "$files_file" "cremaster:$files_file"
scp ./*.xz "cremaster:$repo_path"
