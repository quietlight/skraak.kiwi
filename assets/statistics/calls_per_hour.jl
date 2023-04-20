# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DuckDB, Dates, Statistics, VegaLite

function get_calls_per_hour()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    COALESCE(SUM(CAST(l.male AS INT)) + SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)) + SUM(CAST(l.duet AS INT)), 0) AS calls,
    COALESCE(SUM(CAST(l.male AS INT)) + SUM(CAST(l.duet AS INT)), 0) AS male,
    COALESCE(SUM(CAST(l.female AS INT)) + SUM(CAST(l.duet AS INT)), 0) AS female,
    COALESCE(SUM(CAST(l.duet AS INT)), 0) AS duet,
    time_bucket(INTERVAL '60 minutes', f.local_date_time) AS bucket,
  FROM
    pomona_labels_20230418 AS l
  RIGHT OUTER JOIN
    (SELECT * FROM pomona_files WHERE night=true) AS f
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

println("Mean: ", round(mean(df1.calls), digits=2), " calls per hour")

rename!(df1, Dict(:bucket => "hour_bucket"))
description=describe(df1)[:,1:5]
something.(description, missing) |> CSV.write("./_assets/statistics/tableinput/calls_per_hour_description.csv")

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
df2=combine(df2, :calls => mean, :male => mean, :female => mean, :duet => mean)
rename!(df2, Dict(:bucket => "hour_bucket"))
CSV.write("./_assets/statistics/tableinput/calls_per_hour.csv", df2)
m=DataFrame(hour_bucket=df2.hour_bucket, mean=df2.male_mean, type="male")
f=DataFrame(hour_bucket=df2.hour_bucket, mean=df2.female_mean, type="female")
g1=vcat(m, f)
X = g1 |>
  @vlplot(
    :bar,
    x=:hour_bucket,
    y=:mean,
    color=:type,
    width=400,
    height=400
  )
save("./_assets/statistics/calls_per_hour.png", X)  

# By Month
df3=DataFrame(df)
df3.bucket = map(x -> month(x), df3.bucket)
df3=groupby(df3, :bucket)
df3=combine(df3, :calls => mean, :male => mean, :female => mean, :duet => mean)
rename!(df3, Dict(:bucket => "month"))
CSV.write("./_assets/statistics/tableinput/calls_per_hour_by_month.csv", df3)
m1=DataFrame(month=df3.month, mean=df3.male_mean, type="male")
f1=DataFrame(month=df3.month, mean=df3.female_mean, type="female")
g2=vcat(m1, f1)
Y = g2 |>
  @vlplot(
      :bar,
      x=:month,
      y=:mean,
      color=:type,
      width=400,
      height=400
  )
save("./_assets/statistics/calls_per_hour_by_month.png", Y)