thisFile = fileparts(mfilename('fullpath'));
run(fullfile(thisFile,'config.m'));

files = { ...
    "humidity_supply_points.csv", ...
    "target_temperature_supply_points.csv", ...
    "temperature_supply_points.csv", ...
    "valve_level_supply_points.csv" ...
};

for k = 1:numel(files)
    f = fullfile(RAW_DIR, files{k});
    fprintf("\n==== %s ====\n", files{k});

    ds = datastore(f, 'Type','tabulartext', 'ReadSize', 5e5);
    ds.SelectedVariableNames = {'serialNumber','locationId','type','unit','deviceId','value','time'};

    chunk = read(ds);

    fprintf("Rows read: %d\n", height(chunk));
    disp("Unique types (first chunk):"); disp(unique(chunk.type))
    disp("Units (first chunk):");       disp(unique(chunk.unit))
    disp("Value range (first chunk):"); disp([min(chunk.value) max(chunk.value)])

    % time sanity (nanoseconds)
    tsec = double(chunk.time(1:5)) / 1e9;
    disp("First 5 timestamps as datetime (UTC):");
    disp(datetime(tsec,'ConvertFrom','posixtime','TimeZone','UTC'))
end
