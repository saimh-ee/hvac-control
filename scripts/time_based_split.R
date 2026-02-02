library(data.table)

# Paths
repo_dir <- "C:/Users/saimh/Desktop/hvac-control"
in_path  <- file.path(repo_dir, "data/processed/control_dataset_5min.csv")

# Load dataset
dt <- fread(in_path)
dt[, time := as.POSIXct(time, tz = "UTC")]

# Sort by time (critical)
setorder(dt, time)

N <- nrow(dt)

# Indices for time-based split
idx_train <- floor(0.70 * N)
idx_val   <- floor(0.85 * N)

train <- dt[1:idx_train]
val   <- dt[(idx_train + 1):idx_val]
test  <- dt[(idx_val + 1):N]

# Save
fwrite(train, file.path(repo_dir, "data/processed/control_train.csv"))
fwrite(val,   file.path(repo_dir, "data/processed/control_val.csv"))
fwrite(test,  file.path(repo_dir, "data/processed/control_test.csv"))

# Sanity check
cat("Rows:\n")
cat("  Train:", nrow(train), "\n")
cat("  Val  :", nrow(val), "\n")
cat("  Test :", nrow(test), "\n\n")

cat("Time ranges:\n")
cat("  Train:", format(range(train$time)), "\n")
cat("  Val  :", format(range(val$time)), "\n")
cat("  Test :", format(range(test$time)), "\n")
