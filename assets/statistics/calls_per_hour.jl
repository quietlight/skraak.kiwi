# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DuckDB, Dates, Statistics, VegaLite

function get_calls_per_hour()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/USB/AudioData.db")
  a=DBInterface.execute(con, "
  SELECT
    SUM(CAST(l.male AS INT)) + SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)) + SUM(CAST(l.duet AS INT)) AS Individual,
    time_bucket(INTERVAL '60 minutes', f.local_date_time) AS bucket
  FROM
    pomona_labels_current AS l
  INNER JOIN
    pomona_files AS f
  ON
    l.location = f.location AND l.file = f.file

  GROUP BY
    bucket
  ORDER BY
    bucket;  
  ")
  DBInterface.close!(con)
  
  return a
end

df=get_calls_per_hour()

# Aggregate
df1=DataFrame(df)

println("Mean: ", round(mean(df1.Individual), digits=2))

rename!(df1, Dict(:bucket => "hour_bucket", :Individual => "calls"))
description=describe(df1)[:,1:5]
description[2,2]=0
CSV.write("./_assets/statistics/tableinput/calls_per_hour_description.csv", description)

W = df1 |>
  @vlplot(
    :point, 
    x=:hour_bucket, 
    y=:calls,
    width=400,
    height=400
  )
save("./_assets/statistics/calls_per_hour_aggregate.png", W)

df1.hour_bucket=map(x -> 1, df1.hour_bucket)
rename!(df1, Dict(:hour_bucket => "count"))
df1 = groupby(df1, :calls)
df1 = combine(df1, :count => sum )
rename!(df1, Dict(:calls => "calls_per_hour", :count_sum => "frequency"))
V = df1 |>
  @vlplot(
    :bar,
    x=:calls_per_hour,
    y=:frequency,
    width=400,
    height=400
  )
save("./_assets/statistics/calls_per_hour_frequency.png", V)

# By Hour
df2=DataFrame(df)
df2.bucket = map(x -> hour(x), df2.bucket)
df2=groupby(df2, :bucket)
df2=combine(df2, :Individual => mean)
rename!(df2, Dict(:bucket => "hour_bucket", :Individual_mean => "mean_calls"))
CSV.write("./_assets/statistics/tableinput/calls_per_hour.csv", df2)
X = df2 |>
  @vlplot(
    :bar,
    x=:hour_bucket,
    y=:mean_calls,
    width=400,
    height=400
  )
save("./_assets/statistics/calls_per_hour.png", X)  

# By Month
df3=DataFrame(df)
df3.bucket = map(x -> month(x), df3.bucket)
df3=groupby(df3, :bucket)
df3=combine(df3, :Individual => mean)
rename!(df3, Dict(:bucket => "month", :Individual_mean => "mean_calls_per_hour"))
CSV.write("./_assets/statistics/tableinput/calls_per_hour_by_month.csv", df3)
Y = df3 |>
  @vlplot(
      :bar,
      x=:month,
      y=:mean_calls_per_hour,
      width=400,
      height=400
  )
save("./_assets/statistics/calls_per_hour_by_month.png", Y)