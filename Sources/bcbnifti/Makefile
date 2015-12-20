export CC=gcc
#-Wno-unused-but-set-variable there is a variable in nifti_io.c which isn't used ... 
export CFLAGS=-Wall -std=c99 -pedantic -g -Wno-unused-variable
export LDFLAGS=
export AR=ar

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
export INC=-I$(ROOT_DIR)

#mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
#current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

FSLIO_DIR=fslio
NIFTIIO_DIR=niftiio
ZNZLIB_DIR=znzlib

LIBS=-lm -lz

LIBDIR=znzlib niftiio fslio

EXEC=bcbnifti main

all: lib main

libznz.a: 
	cd znzlib && ${MAKE}

libniftiio.a: libznz.a

libfslio.a:  

#Rule to compile and create all libs
lib:
	for dir in $(LIBDIR); do \
		cd $$dir && $(MAKE); \
		cd ..; \
	done

main : main.o znzlib/libznz.a
	$(CC) $(CFLAGS) ${LDFLAGS} -o $@ $^ ${LIBS}

main.o : main.c
	$(CC) $(CFLAGS) ${LDFLAGS} -o $@ -c $^

bcbnifti : bcbnifti.o
	$(CC) $(CFLAGS) -o $@ $^

bcbnifti.o : bcbnifti.c bcbnifti.h
	$(CC) $(CFLAGS) -o $@ -c $<

clean :
	$(RM) -rf *.o
	for dir in $(LIBDIR); do \
		cd $$dir && $(MAKE) $@; \
		cd ..; \
	done

mrproper : clean
	$(RM) -rf $(EXEC)
	for dir in $(LIBDIR); do \
		cd $$dir && $(MAKE) $@; \
		cd ..; \
	done
