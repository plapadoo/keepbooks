#!/usr/bin/env bash

set -e
shopt -s extglob

mkdir -p packaging/src/keepbooks
cp -R !(packaging) packaging/src/keepbooks
cd packaging
makepkg --noextract
repo-add "$HOME/repo.db.tar.gz" ./*.xz
