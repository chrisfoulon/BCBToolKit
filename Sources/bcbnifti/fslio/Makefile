PROJNAME = fslio

OBJS=fslio.o

SCRIPTS = remove_ext fsloutputtype imtest imglob imcp imln imrm immv

all: libfslio.a

$(OBJS): fslio.c fslio.h
	$(CC) $(CFLAGS) -o $@ -c $< $(INC)

libfslio.a: $(OBJS)
	$(AR) -r libfslio.a $(OBJS)
	
clean:
	rm -rf *.o
	
mrproper: clean
	rm -rf *.a