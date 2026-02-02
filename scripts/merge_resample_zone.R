library(data.table)

repo_dir <- "C:/Users/saimh/Desktop/hvac-control"

temp_path  <- file.path(repo_dir, "data/processed/temperature_zone.csv")
valve_path <- file.path(repo_dir, "data/processed/valve_zone.csv")
set_path   <- file.path(repo_dir, "data/processed/target_zone.csv")

# Load
temp  <- fread(temp_path)
valve <- fread(valve_path)
tset  <- fread(set_path)

# Ensure time is POSIXct
temp[,  time := as.POSIXct(time, tz="UTC")]
valve[, time := as.POSIXct(time, tz="UTC")]
tset[,  time := as.POSIXct(time, tz="UTC")]

# Range for common grid (overlap window)
t_start <- max(min(temp$time), min(valve$time), min(tset$time))
t_end   <- min(max(temp$time), max(valve$time), max(tset$time))

cat("Overlap window:\n")
cat("  start:", format(t_start), "\n")
cat("  end  :", format(t_end), "\n")

# 5-minute grid (change "5 min" if you want 1 min / 10 min)
grid <- data.table(time = seq(from = t_start, to = t_end, by = "5 min"))

# Key for rolling joins
setkey(grid, time)
setkey(temp, time)
setkey(valve, time)
setkey(tset, time)

# Rolling join: take last known sample at or before grid time (LOCF)
merged <- temp[grid, roll = TRUE][, .(time, T_in)]
merged <- valve[merged, roll = TRUE][, .(time, T_in, valve)]
merged <- tset[merged, roll = TRUE][, .(time, T_in, valve, T_set)]

# Drop rows that still have NAs (early part where no previous sample exists)
merged <- merged[complete.cases(merged)]

# Save
out_csv <- file.path(repo_dir, "data/processed/zone_merged_5min.csv")
fwrite(merged, out_csv)

cat("Saved:", out_csv, "\n")
cat("Rows:", nrow(merged), "\n")
print(head(merged, 10))

# Quick sanity ranges
cat("Ranges:\n")
cat("  T_in :", paste(range(merged$T_in), collapse=" to "), "\n")
cat("  T_set:", paste(range(merged$T_set), collapse=" to "), "\n")
cat("  valve:", paste(range(merged$valve), collapse=" to "), "\n")
