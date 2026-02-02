library(data.table)
library(R.matlab)

repo_dir <- "C:/Users/saimh/Desktop/hvac-control"
in_csv  <- file.path(repo_dir, "data/processed/zone_merged_5min.csv")
out_csv <- file.path(repo_dir, "data/processed/control_dataset_5min.csv")
out_mat <- file.path(repo_dir, "data/processed/control_dataset_5min.mat")

dt <- fread(in_csv)
dt[, time := as.POSIXct(time, tz="UTC")]

# Clean + features
dt[, valve := pmax(0, pmin(100, as.numeric(valve)))]
dt[, u := valve / 100.0]
dt[, e := T_set - T_in]         # control error (°C)
dt[, dT := c(NA, diff(T_in))]   # simple temp change per 5-min step (optional)
dt <- dt[!is.na(dT)]            # drop first row

# Save CSV
fwrite(dt, out_csv)
cat("Saved:", out_csv, "\n")
cat("Rows:", nrow(dt), "\n")
print(head(dt, 5))

# Save MAT for Simulink
# Convert time to seconds since start (common in Simulink)
t0 <- dt$time[1]
t_sec <- as.numeric(difftime(dt$time, t0, units="secs"))

R.matlab::writeMat(
  out_mat,
  t_sec = t_sec,
  T_in  = dt$T_in,
  T_set = dt$T_set,
  e     = dt$e,
  valve = dt$valve,
  u     = dt$u,
  dT    = dt$dT
)

cat("Saved:", out_mat, "\n")
