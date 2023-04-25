# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DataFramesMeta, DuckDB, Dates, Statistics, VegaLite

function get_calls_with_location(loc::String)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    file,
    COALESCE(CAST(male AS INT), 0) AS male,
    COALESCE(CAST(female AS INT), 0) AS female,
    COALESCE(CAST(duet AS INT), 0) AS duet,
  FROM
    secretary_island_labels_20230405
  WHERE
    location = '$loc';
  
  ")
  DBInterface.close!(con) 
  a=DataFrame(a) 
  return a
end

function get_files_with_location(loc::String)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    file,
    time_bucket(INTERVAL '60 minutes', local_date_time) AS bucket
  FROM
    secretary_island_files
  WHERE
    location = '$loc'
  
  ")
  DBInterface.close!(con) 
  a=DataFrame(a)
  return a
end

function get_location_calls_per_hour(loc::String)
  l=DataFrame(get_calls_with_location("$loc"))
  f=DataFrame(get_files_with_location("$loc"))
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

function get_location_list()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
    SELECT
      l.location AS locations,
      SUM(CAST(l.male AS INT)) + SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)) + SUM(CAST(l.duet AS INT)) AS calls,
    FROM 
      secretary_island_labels_20230405 AS l
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

function graph_data()
  df = DataFrame(
    location = String[],
    male = Float64[],
    female = Float64[],
    duet = Float64[]
  )

  for location in get_location_list()
    x=get_location_calls_per_hour(location)
    push!(df, x)
  end
  @transform!(df, @byrow :individual = (:male + :female) |> x -> round(x, digits=4))
  m=DataFrame(location=df.location, mean_calls_per_hour=df.male, type="male")
  f=DataFrame(location=df.location, mean_calls_per_hour=df.female, type="female")
  dfx=vcat(m, f)
  println("Mean calls per hour by location: $(df.individual |> mean |> x -> round(x, digits=4))")

  #for table
  sort!(df, [:individual], rev=true)
  push!(df, ["TOTAL", df.male |> mean |> x -> round(x, digits=4), df.female |> mean |> x -> round(x, digits=4), df.duet |> mean |> x -> round(x, digits=4), df.individual |> mean |> x -> round(x, digits=4)])
  CSV.write("./_assets/statistics/tableinput/secretary_island_calls_per_hour_by_location.csv", df)
  
  return dfx
end

df=graph_data()
X = df |>
  @vlplot(
    :bar,
    x=:location,
    y=:mean_calls_per_hour,
    color=:type,
    width=400,
    height=400,
  )
save("./_assets/statistics/secretary_island_calls_per_hour_by_location.png", X)