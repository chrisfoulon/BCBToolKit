PROJNAME = znzlib

OBJS=znzlib.o

all: libznz.a

$(OBJS):  znzlib.c znzlib.h
	$(CC) $(CFLAGS) -o $@ -c $< $(INC)

libznz.a: $(OBJS)
	$(AR) -r libznz.a $(OBJS)

clean:
	rm -rf *.o
	
mrproper: clean
	rm -rf *.a