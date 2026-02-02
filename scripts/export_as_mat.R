library(data.table)
library(R.matlab)

repo_dir <- "C:/Users/saimh/Desktop/hvac-control"

train <- fread(file.path(repo_dir, "data/processed/control_train.csv"))
val   <- fread(file.path(repo_dir, "data/processed/control_val.csv"))
test  <- fread(file.path(repo_dir, "data/processed/control_test.csv"))

to_mat <- function(dt){
  dt[, time := as.POSIXct(time, tz="UTC")]
  t0 <- dt$time[1]
  list(
    t_sec = as.numeric(difftime(dt$time, t0, units="secs")),
    T_in  = dt$T_in,
    T_set = dt$T_set,
    u     = dt$u,
    valve = dt$valve,
    e     = dt$e
  )
}

tr <- to_mat(train)
va <- to_mat(val)
te <- to_mat(test)

writeMat(file.path(repo_dir, "data/processed/split_train.mat"),
         t_sec=tr$t_sec, T_in=tr$T_in, T_set=tr$T_set, u=tr$u, valve=tr$valve, e=tr$e)

writeMat(file.path(repo_dir, "data/processed/split_val.mat"),
         t_sec=va$t_sec, T_in=va$T_in, T_set=va$T_set, u=va$u, valve=va$valve, e=va$e)

writeMat(file.path(repo_dir, "data/processed/split_test.mat"),
         t_sec=te$t_sec, T_in=te$T_in, T_set=te$T_set, u=te$u, valve=te$valve, e=te$e)

cat("Saved: split_train.mat, split_val.mat, split_test.mat\n")
