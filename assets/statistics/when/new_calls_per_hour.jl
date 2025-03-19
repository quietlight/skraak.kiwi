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
  cdf.location_count=ones(Int, nrow(cdf))
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

function get_data()
  df = DataFrame(
    bucket = DateTime[],
    male = Float64[],
    female = Float64[],
    duet = Float64[],
    location_count = Int64[]
  )

  for location in get_location_list()
    x=get_location_calls_per_hour(location)
    for row in eachrow(x)
      push!(df, (bucket = row.bucket, male = row.male, female = row.female, duet = row.duet, location_count = row.location_count))
    end
  end

  @transform!(df, @byrow :individual = (:male + :female))
  gdf = groupby(df, :bucket)
  cdf = combine(gdf, :male => sum, :female => sum, :duet => sum, :individual => sum, :location_count => sum)
  @transform!(cdf, @byrow :male = (:male_sum / :location_count_sum))
  @transform!(cdf, @byrow :female = (:female_sum / :location_count_sum))
  @transform!(cdf, @byrow :duet = (:duet_sum / :location_count_sum))
  @transform!(cdf, @byrow :individual = (:individual_sum / :location_count_sum))
  @transform!(cdf, @byrow :month = month(:bucket))
  @transform!(cdf, @byrow :hour = hour(:bucket))
  select!(cdf, Not([:male_sum, :female_sum, :duet_sum, :individual_sum, :location_count_sum, :bucket ]))
  return cdf
end

df=get_data()

function month_graph(df)
  select!(df, Not([:hour ]))
  gdf = groupby(df, :month)
  cdf = combine(gdf, :male => mean, :female => mean, :duet => mean, :individual => mean)
  select!(cdf, Not([:duet_mean, :individual_mean]))
  tdf=DataFrame(month=vcat(cdf.month, cdf.month), mean=vcat(cdf.male_mean, cdf.female_mean), type=(vcat(["male" for x in 1:nrow(cdf)], ["female" for x in 1:nrow(cdf)])))
  return tdf
end

function hour_graph(df)
  select!(df, Not([:month ]))
  gdf = groupby(df, :hour)
  cdf = combine(gdf, :male => mean, :female => mean, :duet => mean, :individual => mean)
  select!(cdf, Not([:duet_mean, :individual_mean]))
  sdf=cdf[6:19, :]
  tdf=DataFrame(hour=vcat(sdf.hour, sdf.hour), mean=vcat(sdf.male_mean, sdf.female_mean), type=(vcat(["male" for x in 1:nrow(sdf)], ["female" for x in 1:nrow(sdf)])))
  return tdf
end

# println(hour_graph(copy(df)))
# println(month_graph(copy(df)))

X = hour_graph(copy(df)) |>
  @vlplot(
    :bar,
    y=:mean,
    x=:hour,
    color=:type,
    width=400,
    height=400,
  )
save("./_assets/statistics/new_calls_per_hour.svg", X)

Y = month_graph(copy(df)) |>
  @vlplot(
    :bar,
    y=:mean,
    x=:month,
    color=:type,
    width=400,
    height=400,
  )
save("./_assets/statistics/new_calls_per_hour_by_month.svg", Y)