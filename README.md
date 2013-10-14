# misc-scripts

Some tools I've written over the years to help with various tasks. A
couple of these are half-decent examples of the scripter's art; most are
nothing special, a couple are borderline disgusting. They've all been
very useful to me though, and are here primarily so I can get hold of
them when I need them. YMMV.

## cs

Replaces spaces with underscores, removes anything else that's
non-alphanumeric, and flattens the case of filenames. Crudely thrown
together in shell.

    $ cs file...

## mmv

    $ mmv search replace

Renames all files in the current working directory such that `search`
becomes `replace`. Ultra-crude shell.

## patch_system.sh

## random_files.rb

    $ random_files.rb [-neONrRxsSvDh] -d target dir...

Recursively `find`s all the files in one or more directories, then
symlinks a given number of them, chosen at random, into a target
directory. It is able to obscure the link target by linking with a hash
of the original name, or based on a pattern taken from the target
directory name. You can control which files to match with `mtime`
parameters passed through to `find`; and filter by filename extension or
by matching filenames against a regular expression. Run with `-h` for
more info.

## un

A rough shell wrapper round various archivers.

     $ un file...

## remote.sh

A wrapper to `konsole` and `gnome-terminal` that opens you a new window
on one or more hosts. Run with `-h` for usage.

