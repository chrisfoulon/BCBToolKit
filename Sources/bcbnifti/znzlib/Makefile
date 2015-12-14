PROJNAME = znzlib

LIBS = -lznz -lm -lz 

OBJS=znzlib.o

all: libznz.a

libznz.a: ${OBJS}
	${AR} -r libznz.a ${OBJS}
