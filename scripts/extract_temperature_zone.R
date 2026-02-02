library(data.table)
library(bit64)

repo_dir <- "C:/Users/saimh/Desktop/hvac-control"
data_dir <- "C:/Users/saimh/Downloads/Temperature control data"
temp_file <- file.path(data_dir, "temperature_supply_points.csv")

SER <- "00158D0001922E3A"
LOC <- "5c6d4ff50f6b6400017e38ba"

# Read only needed columns; fill handles messy rows
dt <- fread(
  temp_file,
  fill = TRUE,
  select = c("serialNumber","locationId","deviceId","value","time","unit","type"),
  showProgress = TRUE
)

# Filter zone
z <- dt[serialNumber == SER & locationId == LOC]

cat("Rows matched:", nrow(z), "\n")
if (nrow(z) == 0) stop("No rows matched SER/LOC")

# Clean types
z[, value := as.numeric(value)]
z[, time  := as.integer64(time)]

# Convert time (ns -> seconds -> POSIXct)
z[, time_utc := as.POSIXct(as.numeric(time) / 1e9, origin="1970-01-01", tz="UTC")]

# Final table
zone_temp <- z[!is.na(time_utc) & !is.na(value), .(time = time_utc, T_in = value)]
setorder(zone_temp, time)
zone_temp <- unique(zone_temp, by="time")

out_path <- file.path(repo_dir, "data/processed/temperature_zone.csv")
fwrite(zone_temp, out_path)

cat("Saved:", out_path, "\n")
cat("Rows saved:", nrow(zone_temp), "\n")
print(head(zone_temp, 10))
