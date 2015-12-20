PROJNAME = znzlib

LIBS = -lznz -lm -lz 

OBJS=znzlib.o

all: libznz.a

libznz.a: znzlib.o
	${AR} -r libznz.a znzlib.o

# -I/usr/include

znzlib.o: znzlib.c znzlib.h
	gcc -Wall -std=c99 -pedantic -g -Wno-unused-variable -o $@ -c $<
	
clean:
	rm -rf *.o
	
mrproper: clean
	rm -rf *.a