#include "bcbnifti.h"

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
  /* Write code to modify data here*/
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
  printf("Hello World\n");
    exit(EXIT_SUCCESS);
}
