# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DataFramesMeta, DuckDB, Dates, Statistics

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

#=
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
=#

function get_calls_with_location_trip_date(loc::String, td::Dates.Date)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    file,
    COALESCE(CAST(male AS INT), 0) AS male,
    COALESCE(CAST(female AS INT), 0) AS female,
    COALESCE(CAST(duet AS INT), 0) AS duet,
  FROM
    (
        SELECT l.*, f.file, f.location, f.trip_date
    FROM pomona_labels_20230418 l
    LEFT JOIN pomona_files f
    ON l.file = f.file AND l.location = f.location
    WHERE f.trip_date = (DATE '$td')
        )
  WHERE
    location = '$loc' AND trip_date = (DATE '$td');
  ")
  DBInterface.close!(con) 
  a=DataFrame(a) 
  return a
end

function get_files_with_location_trip_date(loc::String, td::Dates.Date)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    file,
    time_bucket(INTERVAL '60 minutes', local_date_time) AS bucket,
    night,
  FROM
    pomona_files
  WHERE
    location = '$loc' AND trip_date = (DATE '$td');
  
  ")
  DBInterface.close!(con) 
  a=DataFrame(a)
  b=filter(row -> row.night = true, a)
  select!(b, Not([:night]))
  return b
end

function get_location_trip_date_calls_per_hour(loc::String, td::Dates.Date)
  l=DataFrame(get_calls_with_location_trip_date("$loc", td))
  f=DataFrame(get_files_with_location_trip_date("$loc", td))
  df=outerjoin(f, l, on = :file)
  select!(df, Not([:file]))
  df=coalesce.(df, 0)
  gdf = groupby(df, :bucket)
  cdf = combine(gdf, :male => sum, :female => sum, :duet => sum)
  @transform!(cdf, @byrow :male = :male_sum + :duet_sum)
  @transform!(cdf, @byrow :female = :female_sum + :duet_sum)
  rename!(cdf, :duet_sum => :duet)
  select!(cdf, Not([:male_sum, :female_sum]))
  # there is a lot of data here for further analysis, for now mean calls only.
  mm=round(mean(cdf.male); digits=4)
  fm=round(mean(cdf.female); digits=4)
  dm=round(mean(cdf.duet); digits=4)
  row = [loc, mm, fm, dm]
  return row
end

function get_location_list_for_trip_date(td::Dates.Date)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
    SELECT
      l.location AS locations,
      SUM(CAST(l.male AS INT)) + SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)) + SUM(CAST(l.duet AS INT)) AS calls,
    FROM 
      (
      SELECT m.*, n.file, n.location, n.trip_date
      FROM pomona_labels_20230418 m
      LEFT JOIN pomona_files n
      ON m.file = n.file AND m.location = n.location
      WHERE n.trip_date = (DATE '$td')
        ) AS l
    WHERE 
      l.male = true OR l.female = true OR l.duet = true
    GROUP BY
      l.location
    ORDER BY
      calls DESC;
  ")
  DBInterface.close!(con)
  a=DataFrame(a)
  return a.locations
end

function trip_date_table(td::Dates.Date)
  df = DataFrame(
    location = String[],
    male = Float64[],
    female = Float64[],
    duet = Float64[]
  )

  for location in get_location_list_for_trip_date(td)
    x=get_location_trip_date_calls_per_hour(location, td)
    push!(df, x)
  end
  @transform!(df, @byrow :individual = (:male + :female) |> x -> round(x, digits=4))
  sort!(df, [:individual], rev=true)
  push!(df, ["TOTAL", df.male |> mean |> x -> round(x, digits=4), df.female |> mean |> x -> round(x, digits=4), df.duet |> mean |> x -> round(x, digits=4), df.individual |> mean |> x -> round(x, digits=4)])
  #CSV.write("./_assets/statistics/tableinput/calls_per_hour_by_location.csv", df)
  return df
end 

for tdate in get_trip_dates()
  cph = trip_date_table(tdate)
  something.(cph, missing) |> CSV.write("./_assets/trips/tableinput/$(tdate)-cph.csv")  
end