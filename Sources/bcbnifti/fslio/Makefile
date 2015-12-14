PROJNAME = fslio

OBJS=fslio.o

SCRIPTS = remove_ext fsloutputtype imtest imglob imcp imln imrm immv

all: libfslio.a

libfslio.a: ${OBJS}
	${AR} -r libfslio.a ${OBJS}

