#!/bin/ksh

# I keep dotfiles in an NFS directory and symlink them into $HOME on different
# OSes. Things with secrets go in 'credentials', things without go in
# 'dotfiles'.

DIRS="${HOME}/work/dotfiles ${HOME}/work/credentials"

for dir in $DIRS
do
	ls $dir | while read f
	do
		target="${HOME}/.${f}"
		[[ -f $target || -L $target ]] && rm $target
		ln -s "${dir}/$f" "$target"
	done
done
