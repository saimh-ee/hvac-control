library(data.table)
library(bit64)

repo_dir <- "C:/Users/saimh/Desktop/hvac-control"
data_dir <- "C:/Users/saimh/Downloads/Temperature control data"
valve_file <- file.path(data_dir, "valve_level_supply_points.csv")

SER <- "00158D0001922E3A"
LOC <- "5c6d4ff50f6b6400017e38ba"

dt <- fread(
  valve_file,
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

z[, valve := as.numeric(value)]
z[, time_ns := as.integer64(time)]
z <- z[is.finite(valve) & !is.na(time_ns)]

z[, time_sec := as.numeric(time_ns %/% as.integer64(1000000000))]
z[, time := as.POSIXct(time_sec, origin="1970-01-01", tz="UTC")]

zone_valve <- z[!is.na(time), .(time, valve)]
setorder(zone_valve, time)
zone_valve <- unique(zone_valve, by="time")

out_path <- file.path(repo_dir, "data/processed/valve_zone.csv")
fwrite(zone_valve, out_path)

cat("Saved:", out_path, "\n")
cat("Rows saved:", nrow(zone_valve), "\n")
print(head(zone_valve, 10))
