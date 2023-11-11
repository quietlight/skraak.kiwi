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
    pomona_labels_20230418
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
    time_bucket(INTERVAL '60 minutes', local_date_time) AS bucket,
    night,
    temp_c AS temp
  FROM
    pomona_files
  WHERE
    location = '$loc'
  
  ")
  DBInterface.close!(con) 
  a=DataFrame(a)
  b=filter(row -> row.night = true, a)
  select!(b, Not([:night]))
  return b
end

function get_location_calls_per_hour(loc::String)
  l=DataFrame(get_calls_with_location("$loc"))
  f=DataFrame(get_files_with_location("$loc"))
  df=outerjoin(f, l, on = :file)
  select!(df, Not([:file]))
  df=coalesce.(df, 0)
  gdf = groupby(df, :bucket)
  cdf = combine(gdf, :male => sum, :female => sum, :duet => sum, :temp => mean)
  @transform!(cdf, @byrow :male = :male_sum + :duet_sum)
  @transform!(cdf, @byrow :female = :female_sum + :duet_sum)
  rename!(cdf, :duet_sum => :duet)
  select!(cdf, Not([:male_sum, :female_sum]))
  # there is a lot of data here for further analysis, for now mean calls only.
  return cdf
end

function get_location_list()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
    SELECT
      l.location AS locations,
      SUM(CAST(l.male AS INT)) + SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)) + SUM(CAST(l.duet AS INT)) AS calls,
    FROM 
      pomona_labels_20230418 AS l
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

function temp_data()
  df = DataFrame(
    bucket = DateTime[],
    duet = Int64[],
    temp_mean = Float64[],
    male = Int64[],
    female = Int64[],
    
  )

  for location in get_location_list()
    x=get_location_calls_per_hour(location)
    y=[df, x]
    df=reduce(vcat, y)
  end
  @transform!(df, @byrow :individual = (:male + :female) |> x -> round(x, digits=4))
  @transform!(df, @byrow :temp = trunc(:temp_mean))
  for row in eachrow(df)
    if row.temp == -0.0
      row.temp = 0.0
    end
  end
  select!(df, :individual, :temp)
  gdf = groupby(df, :temp)
  cdf = combine(gdf, :individual => mean)
  filter!(row -> row.individual_mean > 0, cdf)
  sort!(cdf, [:temp])
  rename!(cdf, :temp => :temperature, :individual_mean => :calls_per_hour)
  #println(cdf)
  return cdf
end

df=temp_data()
X = df |>
  @vlplot(
    :bar,
    x=:temperature,
    y=:calls_per_hour,
    width=400,
    height=400,
  )

save("./_assets/statistics/calls_per_hour_by_temperature.svg", X)