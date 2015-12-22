#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include "znzlib/znzlib.h"
#include "fslio/fslio.h"
#include "niftiio/nifti1_io.h"


int main(int argc, char **argv) {
    int fd = open( "testni", O_RDWR );
    znzFile z = znzdopen(fd, "r", 0);
    znzFile* p = &z;
    Xznzclose(p);
    
    FSLIO *fslio = FslInit();
    /*const char* fname = "/home/tolhs/Tractotron/BCBToolKit/Lesions/lesionpatient1.nii.gz";
    char* varname = "/home/tolhs/MesDocuments/normalize/RES.nii";
    varname = fname;*/
    char* varname = "/home/tolhs/MesDocuments/normalize/RES.nii.gz";
    
    if (nifti_validfilename(varname)) {
	printf("nifti_validfilename(fname) OK.\n");
    }
    FslReadAllVolumes(fslio, varname);
    printf("OK \n");
    //FslClose(fslio);
    //printf("OK2 \n");
    
    printf("DataType : %d\n", fslio->niftiptr->datatype);
    printf("Sizeof int : %lu\n", sizeof(double));
    printf("Datatype to string : %s\n", nifti_datatype_to_string(fslio->niftiptr->datatype));
    
    double*** mat = FslGetVolumeAsScaledDouble(fslio, 0);
    
    for (int i = 0; i < 50; i++) {
      printf("[%f]", mat[i][i][i]);
    }
    
    printf("\nHello world\n");
    return EXIT_SUCCESS;
}
