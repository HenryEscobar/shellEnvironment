#!/bin/sh
# Geek: Henry J. Escobar
# Purpose: Copy the contents of my shell enviroment from github into home dir
# Notes;
#       Tried to use find to build file list but had problems with sub dirs.
#       Will need to try again later
#
#       Debating with self if being explict is better or not
#
# Bugs:

homeFileList=".bashrc .tmux.conf .screenrc .tmux.reset"
sshSubDir="config"

backupTag=`date +%Y%m%d-%H%M%S`
DEBUG=1

if [ $DEBUG -ne 0 ] ; then
    echo "IN DEBUG MODE! Will not put into home directory"
    echo "Change DEBUG mode to 0 if you trust me."
else
    echo "This script will be replacing your enviromnet files. I hope you trust me"
fi

for i in $homeFileList ; do
    if [ -f ~/$i ] ; then
       echo "mv ~/$i ~/$i-$backupTag"
       [ $DEBUG -eq 0 ] && mv ~/$i ~/$i-$backupTag 
    fi
    echo "ln $i ~/"
    [ $DEBUG -eq 0 ] && ln $i ~/
done

for i in $sshSubDir ; do
    if [ ! -d ~/.ssh ] ; then
       mkdir ~/.ssh
       chmod 0700 ~/.ssh
    fi

    if [ -f ~/.ssh/$i ] ; then
       echo "mv ~/.ssh/$i ~/.ssh/$i-$backupTag"
       [ $DEBUG -eq  0 ] && mv ~/.ssh/$i ~/.ssh/$i-$backupTag
    fi

    echo "ln ./.ssh/$i ~/.ssh/"
    [ $DEBUG -eq 0 ] && ln ./.ssh/$i ~/.ssh/

done
