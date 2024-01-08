#!/bin/bash

#+ AUTHOR: 
#+ Za0Warudo, Vinicius Gomes 
#+ 
#+ EMAIL: 
#+ viniciusgomes24@usp.br
#+
#+ DATE: 
#+ 01/06/2024 
#+ 
#+ DESCRIPTION: 
#+ Implementation of a client with named pipes. Based in the EP (Programing Exercise)  
#+ from programming techniques I from IME-USP. The methods includes in the client are listed 
#+ and commented in the help file, that is shared with this code.
#+ 
#+ TESTS:
#+ The program seems works well in the correct use, the tests are based in basic tests of the commands  
#+ and some possibly break cases.

#++ TRAPS ++#
#+ This code specify thaT users logout before leavig, so for the case of interruptions
#+ send a logout is necessary file is crucial. 
function traps
{
	trap "echo $2 $1 logout > /tmp/connection ; exit 10" 0 1 2 3 15 
}
#++ CODE ++#

#+ The server was not open 
if [[ ! -e /tmp/connection ]]
then
	tput setaf 1; tput bold; echo "ERROR: the server is not in execution" >&2 ; tput sgr0 
	exit 1 
fi 	

#++ CLIENT COMMANDS ++# 
function client_commands {
	read -p "<client> " INPUT
	
	if [[ ! -e /tmp/connection  ]]
	then
		#++ The server was closed 
		exit 0

	elif [[ $( cut -f1 -d" " <<< "$INPUT" ) = "login" ]] 
	then  
		#++ Use the silence option to get the password 
		read -sp "Password: " PASS; echo
		INPUT="$INPUT $PASS"
	fi

	if [[ $INPUT = "help" ]] 
	then
		#++ Print the help file 
	    tput setaf 2; tput bold ; cat help_client.txt; echo  ;tput sgr0		
	
	else
	#++ Cooldown to avoid conflict using named pipe 
	sleep .1
	#++ Send the command for server using a named pipe  
	echo "$SCREEN $USER $INPUT" > /tmp/connection
	#++ Get the at the connection
	RETURN=$( cat /tmp/connection )
	if [[ $( cut -f1 -d":" <<< "$RETURN" ) = "1" ]]
	then
		#++ If the operation gone wrong, then the server return "1:ERROR MESSAGE"
		tput setaf 1; tput bold 	
       		cut -f2- -d":" <<< "$RETURN" >&2
	      	tput sgr0	
	elif [[ $( cut -f1 -d":" <<< "$RETURN" ) = "p" ]]
	then
		#++ If the operation return a print, then the server return "p:PRINT MESSAGE"
		 cut -f2- -d":" <<< "$RETURN"
	elif [[ $( cut -f1 -d":" <<< "$RETURN" ) = "l" ]]
	then 
		#++ If the operation return a login. then the server return "l:USER TO SET"
		USER=$( cut -f2- -d":" <<< "$RETURN" )
		#++ Update traps
		traps $USER $SCREEN
	fi
	if [[ $INPUT = "quit" ]]
	then
		#++ Just quit 
	    exit 0	
	fi
	fi
}

#++ SET VARIABLES ++#

#++ Start as none user 
USER=

#++ Save the same of screen
SCREEN=$(tty)

#++ CLIENT LOOP ++#
while true
do
	client_commands 
done 

#++ END ++#
