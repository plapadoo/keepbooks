# keepbooks - simplify your book-keeping!

[![Build Status](https://travis-ci.org/plapadoo/keepbooks.svg?branch=master)](https://travis-ci.org/plapadoo/keepbooks)

`keepbooks` is a little tool to help you with book-keeping. Our general book-keeping workflow is described in detail in [this](https://medium.com/plapadoo/foo) blog post. The technical side of it goes like this:

Put all your book-keeping documents in a folder structure that has categories at the top level (so “invoices”, “vouchers”, …), and immediately below that, put a directory for each year-month pair. So the invoices of January 2020 are kept in `invoices/2020-01` (see the `sample-directory` directory for an example).

To pass on the relevant documents for a single month to your accountant, execute `keepbooks`, passing at least…

 - …the source directory where all of your document history resides
 - …the target directory which might be served via HTTP

`keepbooks` will take the current month and year and copy the relevant directories to the taret directory, keeping the directory/subdirectory structure as it was. `keepbooks` will not change any directories by default (it will do a “dry run”), unless you specify `--wet-run` on the command line.

You can instruct `keepbooks` to use a different month/year using the `--date` argument. Folders can be excluded using `exclude`. Also, group/user rights can be changed using `--user` and `--group`.

## Installation

### Via Docker

The easiest way to try the program is via Docker. Just pull the docker image via

    docker run --rm -v /src:/src -v /dst:/dst plapadoo/keepbooks --source-dir /src --target-dir /dst --user plapadoo --group plapadoo
	
This will pull the official image from [Docker Hub](https://hub.docker.com/r/plapadoo/keepbooks/) and start program.

### Manually

Assuming you have compiled the program yourself, you’re left with a single executable file:  `keepbooks`. You can start it with `--help` to see how it’s used.

## Compilation from source

### Using Nix

The easiest way to compile the bot or the docker image or the program from source is to use the [nix package manager](https://nixos.org/nix/). With it, you can build the program using

    nix-build
	
The resulting files will be located in the `result/` directory. To build the Docker image, use

    nix-build dockerimage.nix
	
This will, at the last line, output a path that you can feed into `docker load`.

### Using cabal

The bot can be compiled using [cabal-install](https://www.haskell.org/cabal/) by using `cabal install --only-dependencies` and then `cabal install`.
