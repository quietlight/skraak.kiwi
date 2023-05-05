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
  cdf = combine(gdf, :male => sum, :female => sum, :duet => sum)
  @transform!(cdf, @byrow :male = :male_sum + :duet_sum)
  @transform!(cdf, @byrow :female = :female_sum + :duet_sum)
  rename!(cdf, :duet_sum => :duet)
  select!(cdf, Not([:male_sum, :female_sum]))
  @transform!(cdf, @byrow :day = Date(:bucket))
  select!(cdf, Not([:bucket]))
  gdf2 = groupby(cdf, :day)
  cdf2 = combine(gdf2, :male => mean, :female => mean, :duet => mean)
  rename!(cdf2, :male_mean => :male, :female_mean => :female, :duet_mean => :duet)
  return cdf2
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

function graph_data()
  df = DataFrame(
    day = Date[],
    male = Float64[],
    female = Float64[],
    duet = Float64[]
  )

  for location in get_location_list()
    x=get_location_calls_per_hour(location)
    df=vcat(df, x)
  end
  gdf = groupby(df, :day)
  cdf = combine(gdf, :male => mean => :male, :female => mean => :female)
  df_rats=DataFrame(CSV.File("/Volumes/SSD1/rats.csv"))
  #@transform!(df_rats, @byrow :ratiness = trunc(:ratiness, digits=1))
  @transform!(df_rats, @byrow :ratiness = round(:ratiness, digits=1))
  select!(df_rats, :Day => :day, :ratiness)
  jdf=innerjoin(cdf, df_rats, on = :day)
  gdf2 = groupby(jdf, :ratiness)
  cdf2 = combine(gdf2, :male => mean => :male, :female => mean => :female)
  sort!(cdf2, [:ratiness])
  filter!(row -> row.ratiness < 1.0, cdf2)
  
  m=DataFrame(ratiness=cdf2.ratiness, calls_per_hour=cdf2.male, type="male")
  f=DataFrame(ratiness=cdf2.ratiness, calls_per_hour=cdf2.female, type="female")
  dfx=vcat(m, f)
  
  return dfx
end

df=graph_data()

X = df |>
  @vlplot(
    :bar,
    x=:ratiness,
    y=:calls_per_hour,
    color=:type,
    width=400,
    height=400,
  )
save("./_assets/statistics/calls_per_hour_by_ratiness.png", X)