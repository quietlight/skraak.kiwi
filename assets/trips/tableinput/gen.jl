# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DataFramesMeta, DuckDB, Dates, Statistics, VegaLite

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
      	SELECT m.*, n.file, n.location, n.trip_date
		FROM pomona_labels_20230418 m
		LEFT JOIN pomona_files n
		ON m.file = n.file AND m.location = n.location
		WHERE n.trip_date = (DATE '$td')
      	)
  WHERE
    location = '$loc';
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

function get_location_calls_per_hour(loc::String, td::Dates.Date)
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

function get_location_list(td::Dates.Date)
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

dxdf = DataFrame(location = String[]) #duet
sxdf = DataFrame(location = String[]) #idividual
mxdf = DataFrame(location = String[]) #male
fxdf = DataFrame(location = String[]) #female

for tdate in get_trip_dates()
  df = DataFrame(
    location = String[],
    male = Float64[],
    female = Float64[],
    duet = Float64[]
  )
  for location in get_location_list(tdate)
  	x=get_location_calls_per_hour(location, tdate)
    push!(df, x)
  end
  @transform!(df, @byrow :individual = (:male + :female) |> x -> round(x, digits=4))
  sort!(df, [:individual], rev=true)
  param=Dates.format(tdate, "yyyy-mm-dd")
  local sdf = DataFrame(
    "location" => copy(df.location),
    param => copy(df.individual)
    )
  local ddf = DataFrame(
    "location" => copy(df.location),
    param => copy(df.duet)
    )
   local mdf = DataFrame(
    "location" => copy(df.location),
    param => copy(df.male)
    )
    local fdf = DataFrame(
    "location" => copy(df.location),
    param => copy(df.female)
    )
  # needs to be here before the push to add total
  global dxdf = outerjoin(dxdf, ddf, on = :location)
  global sxdf = outerjoin(sxdf, sdf, on = :location)
  global mxdf = outerjoin(mxdf, mdf, on = :location)
  global fxdf = outerjoin(fxdf, fdf, on = :location)
  # add total row at bottom of call peer hour table
  push!(df, ["TOTAL", df.male |> mean |> x -> round(x, digits=4), df.female |> mean |> x -> round(x, digits=4), df.duet |> mean |> x -> round(x, digits=4), df.individual |> mean |> x -> round(x, digits=4)])
  CSV.write("./_assets/trips/tableinput/$(tdate)-cph.csv", df)
end

sort!(sxdf)
sort!(dxdf)
sort!(mxdf)
sort!(fxdf)

stack(sxdf, Not([:location]), variable_name=:trip_date, value_name=:calls_per_hour) |> 
  @vlplot(:rect, y=:location, x="trip_date:o", color=:calls_per_hour) |>
  x -> save("./_assets/trips/calls_per_hour_by_location_trip_date.svg", x)
stack(dxdf, Not([:location]), variable_name=:trip_date, value_name=:duets_per_hour) |> 
  @vlplot(:rect, y=:location, x="trip_date:o", color=:duets_per_hour) |>
  x -> save("./_assets/trips/duets_per_hour_by_location_trip_date.svg", x)

#write tables for individual, duet, male, female
something.(sxdf, missing) |> CSV.write("./_assets/trips/tableinput/summary_individual_cph.csv")
something.(dxdf, missing) |> CSV.write("./_assets/trips/tableinput/summary_duets_cph.csv")
something.(mxdf, missing) |> CSV.write("./_assets/trips/tableinput/summary_male_cph.csv")
something.(fxdf, missing) |> CSV.write("./_assets/trips/tableinput/summary_female_cph.csv")

#drop col 2022-03-23 because only N14 serviced and svg's already generated
#lots of locations 2022-04-27 miss out on slope graph for N14/2022-03-23
#if you change anything in the charts I may need to regenerate 2022-03-23 svg's
#by commenting following then build, then uncomment, build again
#####actually nothing burger because 18 moths only just put out there
#left the new 2022-04-27 svg's in though and reverted to normal, so may need to 
#maintain them if I make changes
#select!(mxdf, Not(["2022-03-23"]))
#select!(fxdf, Not(["2022-03-23"]))

#male slope graphs
for col in 3:ncol(mxdf)
  df2=mxdf[:, [1, (col-1), col]] |> dropmissing
  df3=stack(df2, Not([:location]), variable_name=:trip_date, value_name=:calls_per_hour) #|> 
    !isempty(df3) && df3 |> @vlplot(mark={:line,
        strokeWidth=2}, width={step=100}, height=300, y=:calls_per_hour, x={"trip_date:o", scale={padding=0.5}}, color=:location, title="Male Calls per Hour") |> x -> save("./_assets/trips/$(levels(df3.trip_date)[end])-msg.svg", x)   
end

#female slope graphs
for col in 3:ncol(fxdf)
  df2=fxdf[:, [1, (col-1), col]] |> dropmissing
  df3=stack(df2, Not([:location]), variable_name=:trip_date, value_name=:calls_per_hour) #|> 
    !isempty(df3) && df3 |> @vlplot(mark={:line,
        strokeWidth=2}, width={step=100}, height=300, y=:calls_per_hour, x={"trip_date:o", scale={padding=0.5}}, color=:location, title="Female Calls per Hour") |> x -> save("./_assets/trips/$(levels(df3.trip_date)[end])-fsg.svg", x)   
end