PROJNAME = niftiio

LIBS = -lm -lznz -lz

OBJS=nifti1_io.o

all: libniftiio.a

libniftiio.a: ${OBJS}
	${AR} -r libniftiio.a ${OBJS}
