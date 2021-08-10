#!/bin/bash

set -eux

rm -f patchperl-extracted-main.tar.gz
curl -fsSL -o patchperl-extracted-main.tar.gz https://github.com/skaji/patchperl-extracted/archive/main.tar.gz
tar xf patchperl-extracted-main.tar.gz -C patchperl-extracted --strip-components 1
