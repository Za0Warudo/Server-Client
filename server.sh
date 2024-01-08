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
#+ Implementation of a server with named pipes. Based in the EP (Programming Exercise)  
#+ from programming techniques I from IME-USP. The methods includes in the server are listed 
#+ and commented in the help file, that is shared with this code.
#+ 
#+ TESTS:
#+ The program seems works well in the correct use, the tests are based in basic tests of the commands 
#+ and some possibly break cases.

#++ TRAPS ++# 

#+ This code specify that -e /tmp/connection implies server working, so for the case of interruptions
#+ remove the connection file is crucial. 

trap "rm -f /tmp/connection ; exit 10" 0 1 2 3 15 

#++ CODE ++#   

if [[ -e /tmp/connection ]] 
then
	#++ It's not possible to execute two server at same time 
       	tput setaf 1 ; tput bold ; echo "ERROR: the server is already in execution" >&2 ; tput sgr0
	exit 1
fi 

#++ SERVER COMMANDS ++#

function server_commands 
{
	read -p "<server> " INPUT 
	case $INPUT in 

		list)
			#++ Print only the user who are logged in, using extend regular expressions  
			sed -nE  "s/\b(.+)\b \b(.+)\b ON \b(.+)\b/\1/p" $INFO_FILE
			;;
		time) 
			#++ CurrentTime - StartTime = PastTime
			tput setaf 4; tput bold
			echo "$(($(date +%s)-$START_TIME)) seconds"	
			tput sgr0
			;;
		reset)
			#++ Overwrite the original file with a empty one 
			echo -n  > $INFO_FILE 
			;;

		help) 
			#++ Print the help file
			tput bold ; tput setaf 2 ; cat help_server.txt ; echo ; tput sgr0
			;;
		quit)
			#++ Kill the second plane process, by unlocking the read, and removing the connection 
			echo kill > /tmp/connection
			rm /tmp/connection
			rm $INFO_FILE
			exit 0 
			;;
		*)
			#++ Not a include command, so print ERROR
			tput bold ; tput setaf 1 ; echo "ERROR: invalid operation" >&2 ; tput sgr0
			;;
	esac
}

#++ CLIENT COMMANDS ++#

function client_commands 
{
	#++ Catch some basic information about the user and it's request
	REQUEST=$( cat /tmp/connection )
	SCREEN=$( cut -f1 -d" " <<< $REQUEST | cut -f4 -d"/" )
	USER=$( cut -f2 -d" " <<< "$REQUEST" ) 
	COMMAND=$( cut -f3 -d" " <<< "$REQUEST" )
	
	#++ Some operations do not have the 3 parameters, the majority at really 
	P1=$( cut -f4 -d" " <<< "$REQUEST" ); P2=$( cut -f5 -d" " <<< "$REQUEST" ); P3=$( cut -f6 -d" " <<< "$REQUEST" )	
	#++ Cooldown to avoid problems with the named pipe
	sleep .1 

	case $COMMAND in
	
	create)
		if [[ -z $P1 || -z $P2 ]]
		then	
			#++ Less parameters than the expect 
			echo "1:ERROR: create syntax: create <user> <password>" > /tmp/connection  
		elif [[ ! -z $( grep "\b$P1\b" $INFO_FILE ) ]]
		then 
			#++ The user already exists 
			echo "1:ERROR: user already exists" > /tmp/connection
		else
			#++ Everything is correct, could add some fancy message telling that works 
			echo "$P1 $P2 OFF" >> $INFO_FILE
			echo 0 > /tmp/connection
		fi	
			;;
	password)
		if [[ -z $P1 || -z $P2 || -z $P3 ]] 
		then
			#++ Less parameters than the expect
			echo "1:ERROR: password syntax: password <user> <old_password> <new_password>" > /tmp/connection
		elif [[ -z $( grep "\b$P1\b \b$P2\b" $INFO_FILE ) ]] 
		then
			#++ The given user or password don't exists in the users file 
			echo "1:ERROR: user or password invalid" > /tmp/connection
		else
			#++ Replace the old password by the new one, and return sucess 
		      	sed -i "s/\b$P1\b \b$P2\b/$P1 $P3/" $INFO_FILE	
			echo 0 > /tmp/connection
		fi 
			;;
	login)
		if [[ -z $P1 || -z $P2 ]]
		then
			#++ Less parameters than the expect
			echo "1:ERROR: login syntax: login <user> (password claim in the next line)" > /tmp/connection
		elif [[ -z $( grep "\b$P1\b \b$P2\b" $INFO_FILE ) ]] 
		then 
			#++ Not found the user or diffent password
			echo "1:ERROR: user or password invalid" > /tmp/connection 
		elif [[ $( grep "\b$P1\b \b$P2\b" $INFO_FILE | cut -f3 -d' ') = "ON" ]]
		then 
			#++ User found logged 
			echo "1:ERROR: user already logged" > /tmp/connection
		else
			#++ Set logged in the user, and return sucess, the USER variable must be update 
			sed -i "s/\b$P1\b \b$P2\b OFF/$P1 $P2 ON $SCREEN/" $INFO_FILE
			echo "l:$P1" > /tmp/connection
		fi	
			;;
	quit)
		if [[ ! -z $USER ]] 
		then
			#++ Logout the user if it's logged in
			sed -Ei "s/\b$USER\b \b(.+)\b ON \b(.+)\b/$USER \1 OFF/" $INFO_FILE
		fi
		#++ Return sucess
		echo 0 > /tmp/connection 
			;;
	list)
		if [[ -z $USER ]]
		then
			#++ User not logged
		       	echo "1:ERROR: you are not logged" > /tmp/connection	
		else	
			#++ Pick the user logged only with the sed 
			sed -nE "s/\b(.+)\b \b(.+)\b ON \b(.+)\b/\1/p" $INFO_FILE > /dev/pts/$SCREEN
			echo "0" > /tmp/connection
		fi
			;;
	logout)
		if [[ -z $USER ]] 
		then
			#++ Not logged client try to logout
			echo "1:ERROR: you are not logged" > /tmp/connection
		else
			#++ Sucess, replace ON by OFF 
			sed -Ei "s/\b$USER\b \b(.+)\b ON \b(.+)\b/$USER \1 OFF/" $INFO_FILE
			echo "l:" > /tmp/connection
		fi 
			;;
	message)
		if [[ -z $USER ]]
		then 
			#++ User must be logged 
			echo "1:ERROR: you are not logged" > /tmp/connection 
		elif [[ -z $P1 || -z $P2 ]]
		then 
			#++ Invalid syntax
			echo "1:ERROR: message syntax: message <user> <message>" > /tmp/connection
		elif [[ -z $( grep "\b$P1\b" $INFO_FILE ) ]]
		then 
			#++ User not exists 
			echo "1:ERROR: invalid user" > /tmp/connection

		elif [[ $( grep "\b$P1\b" $INFO_FILE | cut -f3 -d" ") = "OFF" ]]
		then 
			#++ User not logged
			echo "1:ERROR: user not logged" > /tmp/connection
		elif [[ $USER = $P1 ]]
		then 
			#++ This program do not support message to yourself
			echo "1:ERROR: cannot send a message to yourself" > /tmp/connection 
		else 
			#++ Format the print message and send to the recipient 
			DEST=$( grep "\b$P1\b" $INFO_FILE | cut -f4 -d" ")	
			MSG=$(cut -f5- -d" " <<< $REQUEST)
			echo > /dev/pts/$DEST
			echo "**********************************" > /dev/pts/$DEST 
			echo "$USER's new message " > /dev/pts/$DEST
			echo "**********************************" > /dev/pts/$DEST 
			echo $MSG > /dev/pts/$DEST
		    	echo "****************************************" > /dev/pts/$DEST
			echo -n "<client> " > /dev/pts/$DEST	
		    echo 0 > /tmp/connection	
		fi 	
			;;
	*) 
		if [[ -e /tmp/connection  ]]
		then 	
			#++ No supported command 
			echo "1:ERROR: invalid operation" > /tmp/connection
		else
			#++ The server was closed, the second plan must be kill 
			exit 0
		fi
	 		;;	
	esac
	#++ Cooldown same as before 
	sleep .75
}

#++ FILE CREATIONS ++# 

#++ Open a communication chanel 
mkfifo /tmp/connection

#++ Save the start time 
START_TIME=$(date +%s)

#++ Make a users data file, very not safe this implementation, but is for didatics purposes  
INFO_FILE=$(mktemp)

#++ CLIENT COMMANDS LOOP ++#
function client_loop 
{
	while true
	do
		client_commands
	done	
}

#++ The loop exec in background 
client_loop &

#++ SERVER COMMANDS LOOP ++#

while true 
do 
	server_commands
done

#++ END ++#
