#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include "znzlib/znzlib.h"
#include "fslio/fslio.h"
#include "niftiio/nifti1_io.h"


int addValTo(double val, double** vec, int index, int len) {
  if (index > len) {
    printf("Erreur : index is greater than the length of the vector\n");
    exit(EXIT_FAILURE);
  }
 
  printf("\n TEst pointeur vec : %p\n", vec);
  
  double* tmp = *vec;
  for (int i = 0; i < len; i ++) {
      printf("[%f]", tmp[i]);
    }
    
    printf("\n");
  double* tab = (double*)malloc(sizeof(*tab) * len + 1);
  for (int i = 0; i < len + 1; i++) {
    if (i < index) {
      tab[i] = tmp[i];
    } else if (i > index) {
      tab[i] = tmp[i - 1];
    } else {
      tab[i] = val;
      printf("\n[%f]\n", tab[i]);
    }
  }
  *vec = tab;
  return len + 1;
}

void copy (void *const dest, void *const src, size_t size) {
   memcpy(dest, src, size);
}

/**
 * We assume that fslio is complete, i.e it contains a header and data.
 */
void createROI(FSLIO* fslio, int x, int y, int z, int radius) {
  int xx,yy,zz,tt;
  
  xx = (fslio->niftiptr->nx == 0 ? 1 : (long)fslio->niftiptr->nx);
  yy = (fslio->niftiptr->ny == 0 ? 1 : (long)fslio->niftiptr->ny);
  zz = (fslio->niftiptr->nz == 0 ? 1 : (long)fslio->niftiptr->nz);
  
  unsigned char   UINT8 = (unsigned char)1;  
  char            INT8 = (char)1;
  unsigned short  UINT16 = (unsigned short)1;
  short           INT16 = (short)1;
  unsigned int    UINT32 = (unsigned int)1;
  int             INT32 = (int)1;
  unsigned long   UINT64 = (unsigned long)1;
  long            INT64 = (long)1;
  float           FLOAT32 = (float)1;
  double          FLOAT64 = (double)1;
  void* p = NULL;
  
  switch(fslio->niftiptr->datatype) {
    case NIFTI_TYPE_UINT8:
      //fslio->niftiptr->data[pos] = UINT8;
      p = &UINT8;
      break;
    case NIFTI_TYPE_INT8:
      p = &INT8;
      break;
    case NIFTI_TYPE_UINT16:
      p = &UINT16;
      break;
    case NIFTI_TYPE_INT16:
      p = &INT16;
      break;
    case NIFTI_TYPE_UINT64:
      p = &UINT64;
      break;
    case NIFTI_TYPE_INT64:
      p = &INT64;
      break;
    case NIFTI_TYPE_UINT32:
      p = &UINT32;
      break;
    case NIFTI_TYPE_INT32:
      p = &INT32;
      break;
    case NIFTI_TYPE_FLOAT32:
      p = &FLOAT32;
      break;
    case NIFTI_TYPE_FLOAT64:
      p = &FLOAT64;
      break;

    case NIFTI_TYPE_FLOAT128:
    case NIFTI_TYPE_COMPLEX128:
    case NIFTI_TYPE_COMPLEX256:
    case NIFTI_TYPE_COMPLEX64:
  default:
  fprintf(stderr, "\nWarning, cannot support %s yet.\n",nifti_datatype_string(fslio->niftiptr->datatype));
      return;
  }
  for (int tx = x - radius; tx < x + radius; tx++) {
    for (int ty = y - radius; ty < y + radius; ty++) {
      for (int tz = z - radius; tz < z + radius; tz++) {
	if (tx < xx && ty < yy && tz < zz) {
	  int pos = tx * ty * tz;
	  
	  copy(fslio->niftiptr->data + pos * (size_t)fslio->niftiptr->datatype, p, (size_t)fslio->niftiptr->datatype);
	}
      }
    }
  }
}

int main(int argc, char **argv) {
    int fd = open( "testni", O_RDWR );
    znzFile z = znzdopen(fd, "rw", 0);
    znzFile* p = &z;
    Xznzclose(p);
    
    FSLIO *fslio = FslInit();
    /*const char* fname = "/home/tolhs/Tractotron/BCBToolKit/Lesions/lesionpatient1.nii.gz";
    char* varname = "/home/tolhs/MesDocuments/normalize/RES.nii";
    varname = fname;*/
    char* varname = "/home/tolhs/MesDocuments/ANACOM/lesions/lesionpatient1.nii.gz";
    
    char** tabl = (char**)malloc(sizeof(*tabl) * 10);
    
    for (int i = 0; i < 10; i++) {
      tabl[i] = (char*)malloc(sizeof(char) * 62);
      sprintf(tabl[i], "/home/tolhs/MesDocuments/ANACOM/lesions/lesionpatient%d.nii.gz", i);
    }
    
    char* output = "/home/tolhs/MesDocuments/ANACOM/lesions/testIMG.nii.gz";
    
    
    FSLIO *out;
    
    FILE* f = fopen(output, "w");
    if (f != NULL)
    {
        fclose(f);
	printf("Ok fopen and fclose\n"); 
    }
    
    if (nifti_validfilename(output)) {
	printf("nifti_validfilename(output) OK.\n");
    }
    FslReadAllVolumes(fslio, varname);
    printf("OK \n");
    
    out = FslOpen(output, "rw");
    
    FslCloneHeader(out, fslio);
    printf("OKCLONE \n");
    FslWriteAllVolumes(out, fslio->niftiptr->data);
    printf("OKWRITE \n");
    //FslClose(fslio);
    //printf("OK2 \n");
    
    printf("DataType : %d\n", fslio->niftiptr->datatype);
    printf("Sizeof int : %lu\n", sizeof(double));
    printf("Datatype to string : %s\n", nifti_datatype_to_string(fslio->niftiptr->datatype));
    
    double*** mat = FslGetVolumeAsScaledDouble(fslio, 0);
    
    
    //createROI(out, 50, 50, 50, 10);
    
    double*** mat2 = FslGetVolumeAsScaledDouble(out, 0);
    
    for (int i = 0; i < 50; i++) {
      printf("[%f]", mat[i][i][i]);
    }
    
    for (int i = 50 * 50 * 50; i < 50 * 50 * 50 + 20; i++) {
      printf("[%f]", mat2[i][i][i]);
    }
    
    printf("\nHello world\n");
    
    double* vec = (double*)malloc(sizeof(*vec) * 10); 
    double* tab = (double*)malloc(sizeof(*tab) * 11);
    
    for (double i = 0; i < 10; i++) { 
      vec[(int)i] = i;
    }
    for (int i = 0; i < 10; i ++) {
      printf("[%f]", vec[i]);
    }
    int len = 10;
    len = addValTo(45.2, &vec, 5, 10);
    printf("\n TEst pointeur : %p\n", vec);
    
    printf("\n TEst pointeur : %p\n", &vec);
    printf("\n");
    printf("TAB\n");
    for (int i = 0; i < len; i ++) {
      printf("[%f]", vec[i]);
    }
    
    printf("TEST\n");
    
    printf("\n");
    exit(EXIT_SUCCESS);
}
