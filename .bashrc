
#echo "bashrc"

alias more=less
alias mroe=less

if [ -f ~/.bashrc-local ] ; then
   .  ~/.bashrc-local 
fi
