#!/bin/sh
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#       
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#       
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

echo "Lib.ru Downloader"
SITE=http://lib.ru
FILE=search.html
BOOKS=books.html
DIR=Книги
FILES="$FILE $BOOKS"
if [ -d $DIR ]
	then true
	else mkdir $DIR
fi
cd $DIR/
echo $pwd
for i in $FILES; do
	if [ -e $i ]
		then rm $i
	fi
done
############################################
#Основные функции
############################################
function search {
	#Получает ссылку на страничку с выполненным поиском
	WORD=$1\
	www=$(echo $WORD|\
	iconv -f utf-8 -t koi8-r|\
	hexdump -e '/1 "%02X"'|\
	sed s/../%\\0/g|\
	sed s/%0A//g;\
	echo)
	SEARCH=http://lib.ru/koi/GrepSearch?Search=$www
	echo $SEARCH
}
function get_links {
	#Получает с поиска ссылки на страницы с книгами и их названия
	LINKS=$(cat $1|\
	iconv -f koi8-r -t utf-8|\
	grep  \\\[dir\\\]|\
	grep -o /koi/[^\>]*)
	for i in $LINKS
	do
		NAME=$(cat $1|\
		iconv -f koi8-r -t utf8|\
		grep $i|\
		grep -om1 '\[dir].*<b>[^<>]*</b>'|\
		sed -e 's/.*<b>\(.*\)<\/b>.*/\1/g'|\
		sed s/\ /_/g|\
		tr -d "\n")
		echo $(echo "$NAME"\|\|\|"$i")
	done
}
function get_books {
	#Получает со страницы ссылки на книги и их названия
	FILE=$1
	BOOKSITE=$2
	BOOKLINK=$(cat $FILE|\
	iconv -f koi8-r -t utf-8 -c|\
	grep -oi \[^=]*.txt\>|
	sed -e 's/>//g')
	for i in $BOOKLINK
	do
		BOOKNAME=$(cat $FILE|\
		iconv -f koi8-r -t utf-8 -c|\
		grep -m1 $i|\
		sed -e 's/.*t><b>\(.*\)<\/b><\/A>.*/\1/g'|\
		sed -e s/\ /_/g)
		echo "$BOOKNAME"\|\|\|"$i"
	done
}
function convert_links {
############################################
#Переделывает ссылки в нужный формат
############################################
	FILES="$1"
	FORMAT=$2
	case $2 in
		"ascii" ) echo $FILES|sed s/.txt/.txt_Ascii.txt/g;echo;;
		"printed") echo $FILES|sed s/.txt/.txt_with-big-pictures.html/g;echo;;
		*) echo $FILES;echo;;
	esac
}
function recode_files {
#Перекодировать файл в выбранную кодировку
	FILE="$1"
	ENCODING="$2"
	if [ $ENCODING = "koi8-r" ];
then
	RIGHTFILE=$FILE
else
	RIGHTFILE=$(cat $FILE|iconv -f koi8-r -t utf-8|iconv -cf utf-8 -t $ENCODING;echo)
	echo $RIGHTFILE > $FILE
fi
}
function rename_files {
	############################################
	#Переименовывает файл в название_книги.txt
	############################################
	FILE=$1
	ENCODING=$2
	LAST_FILENAME=$(cat $FILE|\
	iconv -f $ENCODING -t utf-8|\
	tr "\r" "\n"|\
	tr "\r\n" "\n"|\
	sed -e '/^$/d'|\
	grep -o -m1 '[^\\]*'|\
	sed -e 's/.*<title>\(.*\)<.*title>.*/\1/g'|\
	sed -e 's/^\ //1'|\
	tr -d "\n\r")
	end=$(echo $FILE|grep -o .txt.*;echo)
	mv $FILE "$LAST_FILENAME$end"
}
#############################################
#Начало работы
#############################################
while [ $# -gt 0 ]; do
	case "$1" in
	--help)		shift;echo -e "\tПомощь\t\nДля указания поискового запроса используйте --search <термин>\nДля указания страницы загрузки используйте --page <страница>\nДля указания формата используйте --format <ascii,printed,html>,для указания кодировки используйте --enc <windows-1251,koi8-r,iso-8859-5,mac-cyrillic,cp866,utf-8>";exit ;;
	--page|-p)		shift;PAGE="$1";shift ;;
	--format|-f)	shift;FORMAT="$1";shift;;
	--search|-s)	shift;SEARCHTERM="$1";shift;;
	--enc|-e)		shift;ENCODE="$1";shift;;
	*)				shift;break ;;
	esac
done
if [ -z "$SEARCHTERM" -a -z "$PAGE" ]
then
	echo "Введите название книги или имя автора:"
	read READSEARCH
	SEARCHTERM=$(echo $READSEARCH|
	sed -e s/\ /\\\ /g;echo)
else
	true
fi
if [ -z "$PAGE" ];then
wget -O $FILE $(search "$SEARCHTERM")
else
	true
fi
PS3="Книги? "
if [ -z "$PAGE" ]
then
	select opt in $(get_links "$FILE")
	do
		PAGE=$(echo $opt|grep -o '/koi/.*/'|sed -e "s|.*|$SITE\\0|g")
		break
	done
else
	true
fi
wget -O $BOOKS $PAGE
SELECTBOOKS=$(echo "Всё" $(get_books "$BOOKS" "$PAGE"))
select opt in $SELECTBOOKS
do
if [ $opt = "Всё" ];then
	LINK=$(for i in $SELECTBOOKS;do
	LINK1=$(echo $i|grep -o "|||.*"|sed -e 's/|||//g'|sed -e "s|.*|$PAGE\\0|g")
	echo $LINK1
	done)
	break
else	LINK=$(echo $opt|grep -o "|||.*"|sed -e 's/|||//g'|sed -e "s|.*|$PAGE\\0|g")
		break
fi
done
if [ -z $FORMAT ];
then	FORMAT="html ascii printed"
		select opt in $FORMAT
		do
			RIGHTLINK=$(convert_links "$LINK" $opt)
			break
		done
else	RIGHTLINK=$(convert_links "$LINK" $FORMAT)
fi
wget $RIGHTLINK -nc
RFILE=$(for i in $RIGHTLINK; do
	RFILE1=$(echo $i|grep -o '/[^/]*$'|sed -e 's|/||g')
	echo $RFILE1
done)
###
if [ -z $ENCODE ];then
ENCODE="windows-1251 koi8-r iso-8859-5 mac-cyrillic cp866 utf-8"
select opt in $ENCODE
do
	for i in $RFILE; do
		recode_files $i $opt
		done
	break
done
else
for i in $RFILE; do
		recode_files $i $ENCODE
		done
fi
for i in $RFILE; do
		rename_files $i $ENCODE
		done
###
for i in $FILES; do
	if [ -e $i ]
		then rm $i
	fi
done
