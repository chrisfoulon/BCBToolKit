PROJNAME = znzlib

#LIBS = -lznz -lm -lz 

OBJS=znzlib.o

all: libznz.a

libznz.a: $(OBJS)
	${AR} -r libznz.a $(OBJS)

# -I/usr/include

$(OBJS): znzlib.c znzlib.h
	$(CC) $(CFLAGS) -o $@ -c $< $(INC)
	
clean:
	rm -rf *.o
	
mrproper: clean
	rm -rf *.a