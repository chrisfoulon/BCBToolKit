#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include "fslio/fslio.h"
#include "niftiio/nifti1_io.h"
#include "znzlib/znzlib.h"


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
    case NIFTI_TYPE_UINT8: {
      //fslio->niftiptr->data[pos] = UINT8;
      p = &UINT8;
      //unsigned char *p = (unsigned char *) fslio->niftiptr->data;
      break;
    }
    case NIFTI_TYPE_INT8: {
	//p = &INT8;
	void* p;
	break;
      }
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
  default: {
    void* p;
    fprintf(stderr, "\nWarning, cannot support %s yet.\n",nifti_datatype_string(fslio->niftiptr->datatype));
	return;
    }
  }
  for (int tx = x - radius; tx < x + radius; tx++) {
    for (int ty = y - radius; ty < y + radius; ty++) {
      for (int tz = z - radius; tz < z + radius; tz++) {
	if (tx < xx && ty < yy && tz < zz) {
	  int pos = tx * ty * tz;
	  
	  memcpy(fslio->niftiptr->data + pos * (size_t)fslio->niftiptr->datatype, p, (size_t)fslio->niftiptr->datatype);
	  void* fef = fslio->niftiptr->data + pos * (size_t)fslio->niftiptr->datatype;
	  int* yey = (int*) fef;
	  printf("[%d]", *yey);
	}
      }
    }
  }
}

int main(int argc, char **argv) {
  // lecture 
  char* input = "/home/tolhs/MesDocuments/ANACOM/lesions/another.nii";
  
  char* output = "/home/tolhs/MesDocuments/ANACOM/lesions/out.nii.gz";
  FSLIO* in;
  FSLIO* out;
  short x,y,z,v,dt;
  void *buffer;
  int bufsize;
  in = FslOpen(input,"rb");
  FslGetDim(in,&x,&y,&z,&v);
  bufsize = x * y * z * v * (FslGetDataType(in,&dt) / 8);
  buffer = (void *) calloc(bufsize,1);
  FslReadVolumes(in,buffer,v);
  out = FslOpen(output,"wb");
  
  unsigned char * str = (unsigned char *)buffer;
  for (int i = 0; i < 50; i++) {
    str[i] = (unsigned char)100;
  }
  buffer = (void *)str;
  FslCloneHeader(out,in);
  FslWriteHeader(out);
  
  FslWriteVolumes(out,buffer,out->niftiptr->dim[4]);
  
  printf("fslgetdim in : %d|%d|%d|%d\n", x, y , z, v);
  printf("DataType : %d\n", out->niftiptr->datatype);
  printf("Sizeof int : %lu\n", sizeof(double));
  printf("Datatype to string : %s\n", nifti_datatype_to_string(out->niftiptr->datatype));
  printf("Datatype to string (in): %s\n", nifti_datatype_to_string(in->niftiptr->datatype));
  printf("WriteMode of output : %d\n", out->write_mode);
  
  FslClose(out);
  
  FslClose(in);
  void* b1 = (void *) calloc(bufsize,1);
  void* b2 = (void *) calloc(bufsize,1);
  in = out = NULL;
  in = FslOpen(input,"rb");
  out = FslOpen(output,"rb");
  FslGetDim(in,&x,&y,&z,&v);
  bufsize = x * y * z * v * (FslGetDataType(in,&dt) / 8);
  
  FslReadVolumes(in,b1,v);
  FslReadVolumes(out,b2,v);
  
  unsigned char *bb1 = (unsigned char *) b1;
  unsigned char *bb2 = (unsigned char *) b2;
  
  for (int i = 0; i < 50; i++) {
    printf("[%d]", (unsigned char) bb1[i]);
  }
  printf("\n B2 \n");
  for (int i = 0; i < 50; i++) {
    printf("[%d]", (unsigned char) bb2[i]);
  }
  FslClose(out);
  
  FslClose(in);
  
  /*FSLIO* in = FslOpen(input, "r");
  void *buffer;
  buffer = FslReadAllVolumes(in, input);
  double*** mat = FslGetVolumeAsScaledDouble(in, 0);
  for (int i = 0; i < 50; i++) {
    printf("[%f]", mat[i][i][i]);
  }
  
  // écriture du nouveau fichier
  char* output = "/home/tolhs/MesDocuments/ANACOM/lesions/out.nii.gz";
  FSLIO* fslio;
  fslio = FslOpen(output,"w");
  printf("Open\n");
  FslWriteHeader(fslio);
  printf("WriteHeader\n");
  FslCloneHeader(fslio, in);
  printf("Clone\n");
  FslWriteAllVolumes(fslio, buffer);
  printf("FslWriteAllVolumes\n");
  char* str = (char *)buffer;
  for (int i = 0; i < 50; i++) {
    printf("[%f]", str[i*i*i]);
  }
  short x,y,z,t=1;
  FslGetDim(fslio,&x,&y,&z,&t);
  printf("fslgetdim in : %d|%d|%d|%d\n", x, y , z, t);
  printf("DataType : %d\n", fslio->niftiptr->datatype);
  printf("Sizeof int : %lu\n", sizeof(double));
  printf("Datatype to string : %s\n", nifti_datatype_to_string(fslio->niftiptr->datatype));
  printf("WriteMode of output : %d\n", fslio->write_mode);
  short int* dim = fslio->niftiptr->dim;
  printf("Dimensions : [%d][%d][%d][%d][%d][%d][%d][%d]\n", (int)dim[0], (int)dim[1], (int)dim[2], (int)dim[3], (int)dim[4], (int)dim[5], (int)dim[6], (int)dim[7]);
  dim = in->niftiptr->dim;
  printf("Source Dimensions : [%d][%d][%d][%d][%d][%d][%d][%d]\n", (int)dim[0], (int)dim[1], (int)dim[2], (int)dim[3], (int)dim[4], (int)dim[5], (int)dim[6], (int)dim[7]);
  printf("Nvox in : %d\n", in->niftiptr->nvox);
  printf("Nvox fslio : %d\n", fslio->niftiptr->nvox);
  
  double*** mat2 = FslGetVolumeAsScaledDouble(fslio, 0);
  FslClose(fslio);
  FslClose(in);
  printf("Close\n");*/
  //Pour l'instant, sans ces lignes, il manque les références à la compilation O_____O"
  znzFile fptr;
  fptr = znzopen("/home/tolhs/Tractotron/BCBToolKit/Sources/bcbnifti/testnii","wb",1);
  znzclose(fptr);
  
  printf("Hello World\n");
    exit(EXIT_SUCCESS);
}