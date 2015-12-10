#!/usr/bin/env Rscript

library("oro.nifti")
library("plyr")

args <- commandArgs(TRUE);

getT <- function(x) {    # function to calculate the t-test at each voxel and return the t value
  # we can't calculate a t-test if variance is zero, so check before trying.
  if (var(x) == 0) { stat <- NA; } else { stat <- t.test(x, alternative="greater", mu=0.5)$statistic; }
  
  return(stat)
}

input1 <- args[1]; 
input2 <- args[2];  
output <- args[3];

files1 <- list.files(path = input1, pattern = "*nii*", all.files = TRUE, full.names = TRUE);
files2 <- list.files(path = input2, pattern = "*nii*", all.files = TRUE, full.names = TRUE);

# Une autre façon d'ouvrir une nifti
# fname <- system.file(file.path("nifti", "mniLR.nii.gz"), package="oro.nifti")
# (mniLR <- readNIfTI(fname))
# This is the absolute path of the first file : files1[1]
urlfile <- file.path(files1[1])
mni <- readNIfTI(urlfile)
dim1 <- dim(mni)
voxdim(mni)

url2 <- file.path(files2[1])
mni2 <- readNIfTI(url2)
# Returns a vector of length 3
dim2 <- dim(mni2)
dim2
voxdim(mni2)

big <- array(NA, c(dim1, 2))
big[,,,1] <- mni
big[,,,2] <- mni2

#library(doParallel)
#library(plyr)

#nodes <- detectCores()
#cl <- makeCluster(nodes)
#registerDoParallel(cl)


out <- aaply(big, c(1, 2, 3), getT, .parallel=TRUE);

#stopCluster(cl)

out.nii <- nifti(out, datatype=16, dim=dim1)
out.nii@xyzt_units <- 1;    # voxels in mm
out.nii@qform_code <- 4;   # read from the original files
out.nii@sform_code <- 4;
pixdim(out.nii)[1] <- -1;   # qFactor
pixdim(out.nii)[2:4] <- 2;
pixdim(out.nii)[5:8] <- 1;
writeNIfTI(out.nii, paste0(output, "t_out"));
