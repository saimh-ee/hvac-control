library(data.table)
library(bit64)

repo_dir <- "C:/Users/saimh/Desktop/hvac-control"
data_dir <- "C:/Users/saimh/Downloads/Temperature control data"
target_file <- file.path(data_dir, "target_temperature_supply_points.csv")

SER <- "00158D0001922E3A"
LOC <- "5c6d4ff50f6b6400017e38ba"

dt <- fread(
  target_file,
  sep = ",",
  header = FALSE,
  skip = 1,
  fill = TRUE,
  col.names = c("unit","serialNumber","locationId","externalId","type","deviceId","value","time"),
  na.strings = c("", "NA"),
  showProgress = TRUE
)

z <- dt[serialNumber == SER & locationId == LOC]
cat("Rows matched:", nrow(z), "\n")

z[, T_set := as.numeric(value)]
z[, time_ns := as.integer64(time)]
z <- z[is.finite(T_set) & !is.na(time_ns)]

z[, time_sec := as.numeric(time_ns %/% as.integer64(1000000000))]
z[, time := as.POSIXct(time_sec, origin="1970-01-01", tz="UTC")]

zone_set <- z[!is.na(time), .(time, T_set)]
setorder(zone_set, time)
zone_set <- unique(zone_set, by="time")

out_path <- file.path(repo_dir, "data/processed/target_zone.csv")
fwrite(zone_set, out_path)

cat("Saved:", out_path, "\n")
cat("Rows saved:", nrow(zone_set), "\n")
print(head(zone_set, 10))
cat("T_set range:", paste(range(zone_set$T_set), collapse=" to "), "\n")
