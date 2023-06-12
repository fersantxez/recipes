#!/bin/bash

#flatdir.sh: flattens a hierarchical structure of directories under .
# and moves all files under it to this directory

find ./ -mindepth 2 -type f -exec mv -i '{}' ./ ';'
