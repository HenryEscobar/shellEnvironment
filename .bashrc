
#echo "bashrc"

alias more=less
alias mroe=less

# set terminal title and abuse order of precendence (&& before ||)
function title(){
   [ $# -eq 1 ] && t=$1 || t=`hostname -s `
   printf "\033k$t\033\\"
}

if [ -f ~/.bashrc-local ] ; then
   .  ~/.bashrc-local 
fi

