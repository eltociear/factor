export CC=gcc34
export CFLAGS="-pedantic -Wall -Winline -O2 -march=pentium4 -fomit-frame-pointer"

$CC $CFLAGS -o f native/*.c

strip f

#export CC=gcc
#export CFLAGS="-pedantic -Wall -g"
#
#$CC $CFLAGS -o f-debug native/*.c
