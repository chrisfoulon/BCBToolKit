PROJNAME = niftiio

LIBS = -lm -lznz -lz

OBJS=nifti1_io.o

all: libniftiio.a

${OBJS}:  nifti1_io.c nifti1_io.h nifti1.h
	$(CC) $(CFLAGS) -o $@ -c $< $(INC)

libniftiio.a: $(OBJS)
	$(AR) -r libniftiio.a $(OBJS)

clean:
	rm -rf *.o
	
mrproper: clean
	rm -rf *.a