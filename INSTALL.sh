#!/bin/sh
# Geek: Henry J. Escobar
# Purpose: Copy the contents of my shell enviroment from github into home dir
# Notes;
#	Tried to use find to build file list but had problems with sub dirs.
#	Will need to try again later
#
#       Debating with self if being explict is better or not
#
# Bugs: 

homeFileList=".bashrc .tmux.conf .screenrc .tmux.reset"
sshSubDir="config"

backupTag=`date +%Y%m%d-%H%M%S`

echo "IN DEBUG MODE! Will not put into home directory"

for i in $homeFileist ; do
    if [ -f ~/$i ] ; then
       echo "cp ~/$i ~/$i-$backupTag"
    fi
    echo "ln $i ~/"
done

for i in $sshSubDir ; do
    if [ ! -d ~/.ssh ] ; then
       mkdir ~/.ssh
       chmod 0700 ~/.ssh
    fi 

    if [ -f ~/.ssh/$i ] ; then
       echo "cp ~/.ssh/$i ~/.ssh/$i-$backupTag"
    fi

    echo "ln ./.ssh/$i ~/.ssh/"

done

