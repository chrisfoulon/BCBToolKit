options(warn=0)
args <- commandArgs(TRUE)

# What post-hoc comparison we want to do
mode <- c(co_deco = "Connected versus disconnected",
deco_ctr = "Disconnected versus controls", co_ctr = "Connected versus controls",
classic = "Classic disconnected versus controls")

ph_test <- c(ttest = "t-test", mw = "Mann-Whitney", ks = "Kolmogorov-Smirnov")
ph_fun <- c(ttest = t.test, mw = wilcox.test, ks = ks.test) # access : ph_fun$ks

# The end of the files created by the first part of AnaCOM2
pat_re <- "pat.txt"
sco_re <- "sco.txt"
co_re <- "co_perf.txt"

# Clean way to call/create paths
file_path <- function(dir, filename) {
  file.path(dir, filename, fsep = .Platform$file.sep)
}

# read a csv file in a list
read_txt_in_list <- function(path) {
  return(read.csv(file=path, header=FALSE, sep=","))
}

# We want to know if the second arg is a path or a mean
controls <- function(args2) {
  #ignore warnings
  options(warn=-1)
  nn <- as.numeric(args2)
  if (is.na(nn)) {
    return(args2)
  } else {
    return(nn)
  }
  options(warn=0)
}

# Extract the name of the cluster from the txt file
extract_cluster_name <- function(path, split) {
  filename = basename(path)
  return(strsplit(filename, split)[[1]][1])
}

# Create the list of clusters with the name and score of patients within
# and the scores of patients outside
create_list <- function(p, s, c) {
  df <- list()
  clu_names <- c()
  for (pat in p) {
    clu_names <- c(clu_names, extract_cluster_name(pat, pat_re))
  }
  for (clu in clu_names) {
    pp = c(read_txt_in_list(file_path(folder, paste(clu, pat_re, sep=''))))
    ss = c(read_txt_in_list(file_path(folder, paste(clu, sco_re, sep=''))))
    cc = c(read_txt_in_list(file_path(folder, paste(clu, co_re, sep=''))))
    #print(tt)
    df[[clu]] <- list("pat"=pp, "sco"=ss, "co"=cc)
  }
  return(df)
}

kruskal_on_clusters <- function(list, ctr) {
  cluster <- c()
  kw_pval <- c()
  kw_stat <- c()
  c = unlist(ctr)
  warn = list()
  for (clu in names(list)) {
    p = unlist(list[[clu]]$sco)
    s = unlist(list[[clu]]$co)
    kw = post_hoc(kruskal.test, p, s, c)
    cluster <- c(cluster, clu)
    kw_pval <- c(kw_pval, kw$p.value)
    kw_stat <- c(kw_stat, kw$statistic)
    warn[clu] <- kw$war_err
  }
  li <- data.frame(kw_pval, kw_stat, row.names=cluster)
  return(list("res"=li, "warn"=warn))
}

# Add a column to df with the holm correction of pvalues. The order of df is
# modified
mult_comp_corr <- function(st, col, meth="holm", col_name="holm") {
  st <- st[order(st[col]),]
  tmp <- p.adjust(unlist(st[col]), method=meth)
  st[col_name] <- p.adjust(unlist(st[col]), method=meth)
  return(st)
}

# Compute a post_hoc test and return all the result AND the warnings
post_hoc <- function(func, vec1, vec2, vec_kw=NULL, use_mu=FALSE) {
  withCallingHandlers({
    if (!is.null(vec_kw)) {
      res <- try(func(list(vec1, vec2, vec_kw)), silent = TRUE);
    } else if (use_mu) {
      res <- try(func(vec1, mu=vec2), silent = TRUE);
    } else {
      res <- try(func(vec1, vec2), silent = TRUE);
    }
  }, warning = function(w) {
    warn <<- conditionMessage(w);
    invokeRestart("muffleWarning");
  })
  if (class(res) == "try-error") {
    ww <- "Error : data are essentially constant";
    withCallingHandlers({
        res$p.value <- NaN;
    }, warning = function(w) {
        warnosef <<- conditionMessage(w);
        invokeRestart("muffleWarning");
    })
  }
  if (exists("warn") && !is.null(warn)) {
    w <- paste("Warning", warn, sep=" : ");
    res$war_err = w
  }
  if (exists("ww") && !is.null(ww)) {
    res$war_err = ww
  }
  return(res)
}

# Compute the post_hoc for all clusters in lst, results are added to st
# m is the mode (Between which sets we will do the comparison)
post_hoc_all <- function(func, st, lst, ctr, use_mu, m) {
  warn = list()
  for (clu in row.names(st)) {
    # Disconnected versus connected
    if (m == mode[1] || m == mode[4]) {
      vec1 <- unlist(lst[[clu]]$sco)
      vec2 <- unlist(lst[[clu]]$co)
      st[clu, "nb_disco"] <- length(vec1)
      res <- post_hoc(func, vec1, vec2, use_mu=use_mu)
    # Disconnected versus controls
    } else if (m == mode[2]) {
      vec1 <- unlist(lst[[clu]]$sco)
      res <- post_hoc(func, vec1, ctr, use_mu=use_mu)
      st[clu, "nb_disco"] <- length(vec1)
    # Connected versus controls
    } else if (m == mode [3]) {
      vec1 <- unlist(lst[[clu]]$co)
      res <- post_hoc(func, vec1, ctr, use_mu=use_mu)
      st[clu, "nb_co"] <- length(vec1)
    } else {
      stop("This mode does not exist")
    }
    st[clu, "pval"] <- res$p.value
    st[clu, "stat"] <- res$statistic
    warn[clu] <- res$war_err
  }
  return(list("res"=st, "warn"=warn))
}

#### INITIALIZING ####
# The folder that will contain the txt files of patient's names and scores
folder <- args[1]
# If we want to use mu, ctr is already to the right value and type
ctr <- controls(args[2])
# The selection of the mode we will use for post-hoc comparison
ph_mode <- mode[as.numeric(args[3])]
# The selection of the post_hoc test we will use
test <- ph_test[as.numeric(args[4])]
# The result file, we assume it's parent folders exist
res_folder <- args[5]

# When we need to do a difference, we will notify that we use only a mean
use_mu = is.numeric(ctr)
control_file <- NULL
# If ctr isn't a mean we will read the controls' scores in the text file
if (!use_mu) {
  control_file <- read_txt_in_list(ctr)
  # If we don't use mu, we store the list of scores in ctr
  ctr <- control_file[,1]
}

# We store the lists of the different text files
pat <- list.files(path = folder, pattern = pat_re)
sco <- list.files(path = folder, pattern = sco_re)
co <- list.files(path = folder, pattern = co_re)

ll <- create_list(pat, sco, co)

#### COMPUTATION ####

# table will contain the final results of the post_hoc stats
if (ph_mode != mode["classic"]) {
  liste <- kruskal_on_clusters(ll, ctr)
  st <- liste$res
  kw_warn <- liste$warn
  st <- mult_comp_corr(st, "kw_pval", col_name="kw_holm")
  table <- subset(st, kw_holm < 0.05)
} else {
  # Here we didn't compute Kruskal so we just fill table with the cluster names
  table = data.frame(row.names=names(ll))
}
liste <- post_hoc_all(wilcox.test, table, ll, ctr, use_mu, ph_mode)
res <- liste$res
warn <- liste$warn
# warn

res <- mult_comp_corr(res, "pval")
#### WRITING RESULTS ####

warnings <- data.frame(row.names=names(warn))
warnings$warnings <- unlist(warn)
# warnings$warnings <- warnings[order(row.names(warnings)),]
write.csv(res, "test_rscript.csv", sep=",", fileEncoding="UTF-8")
write.csv(warnings, "test_warn.csv", sep=",", row.names=TRUE,
fileEncoding="UTF-8")
