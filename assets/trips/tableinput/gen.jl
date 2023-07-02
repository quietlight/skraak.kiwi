# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DuckDB

function get_trip_dates()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  	SELECT l.*, f.file, f.location, f.trip_date
	FROM pomona_labels_20230418 l
	LEFT JOIN pomona_files f
	ON l.file = f.file AND l.location = f.location
	; 
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  return levels(df.trip_date)
end

#@info get_trip_dates()

function trip_stats(td::Dates.Date)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  	SELECT location AS Location, 
      SUM(CAST(male AS INT)) AS Solo_Male, 
      SUM(CAST(female AS INT)) AS Solo_Female, 
      SUM(CAST(duet AS INT)) AS Duets, 
      SUM(CAST(male AS INT)) + SUM(CAST(female AS INT)) + SUM(CAST(duet AS INT)) + SUM(CAST(duet AS INT)) AS Individual,
      SUM(CAST(not_kiwi AS INT)) AS False_Positives, 
      SUM(CAST(close_call AS INT)) AS Close,
      SUM(CAST(low_noise AS INT)) AS Low_Noise
      FROM (
      	SELECT l.*, f.file, f.location, f.trip_date
		FROM pomona_labels_20230418 l
		LEFT JOIN pomona_files f
		ON l.file = f.file AND l.location = f.location
		WHERE f.trip_date = (DATE '$td')
      	)
      GROUP BY location
      ORDER BY Individual DESC; 
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  #select!(df, Not([:file_1, :location_1]))
  push!(df, ["TOTAL", sum(df.Solo_Male), sum(df.Solo_Female), sum(df.Duets), sum(df.Individual), sum(df.False_Positives), sum(df.Close), sum(df.Low_Noise), ])
  return df
end

for tdate in get_trip_dates()
	dfx = trip_stats(tdate)
	CSV.write("./_assets/trips/tableinput/$tdate.csv", dfx)
end

function trip_calls_per_hour(td::Dates.Date)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    COALESCE(SUM(CAST(l.male AS INT)) + SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)) + SUM(CAST(l.duet AS INT)), 0) AS calls,
    COALESCE(SUM(CAST(l.male AS INT)) + SUM(CAST(l.duet AS INT)), 0) AS male,
    COALESCE(SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)), 0) AS female,
    COALESCE(SUM(CAST(l.duet AS INT)), 0) AS duet,
    time_bucket(INTERVAL '60 minutes', f.local_date_time) AS bucket,
  FROM (
    SELECT m.*, n.file, n.location, n.trip_date
    FROM pomona_labels_20230418 m
    LEFT JOIN pomona_files n
    ON m.file = n.file AND m.location = n.location
    WHERE n.trip_date = (DATE '$td')
        ) AS l
  RIGHT OUTER JOIN
    (SELECT * FROM pomona_files WHERE night=true AND trip_date = (DATE '$td')) AS f
  ON
    l.location = f.location AND l.file = f.file
  GROUP BY
    bucket
  ORDER BY
    bucket; 
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  rename!(df, Dict(:bucket => "hour_bucket"))
  description=describe(df)[:,1:5]

end

for tdate in get_trip_dates()
  cph = trip_calls_per_hour(tdate)
  something.(cph, missing) |> CSV.write("./_assets/trips/tableinput/$(tdate)-cph.csv")  
end