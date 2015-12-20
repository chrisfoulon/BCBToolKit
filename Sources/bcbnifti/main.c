#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include "znzlib/znzlib.h"

int main(int argc, char **argv) {
    int fd = open( "testni", O_RDWR );
    znzFile z = znzdopen(fd, "r", 0);
    znzFile* p = &z;
    Xznzclose(p);
    
    
    
    
    
    printf("Hello world\n");
    return EXIT_SUCCESS;
}
