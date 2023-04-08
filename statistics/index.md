@def title = "Aggregate Statistics"

# Aggregate Statistics

\tableofcontents

## Audio Recorded

```julia:./tableinput/gen #hideall
using CSV, DataFrames, DuckDB

function get_audio_list()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/USB/AudioData.db")
  a=DBInterface.execute(con, "
    SELECT drive AS Drive,
      ROUND(COUNT(*) * 0.000028, 2) AS SizeTB,
      COUNT(*) AS Files,
      ROUND(SUM(duration_s) / 3600, 1) AS Hours, 
      strftime(MIN(start_rec_period), '%d/%m/%Y') AS From,
      strftime(MAX(end_rec_period), '%d/%m/%Y') AS To,
      FROM pomona_files,
    GROUP BY drive
    ORDER BY drive ASC;
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  return df
end

table=get_audio_list()
CSV.write("./_assets/statistics/tableinput/audio_by_drive.csv", table)
```
\tableinput{}{statistics/tableinput/audio_by_drive.csv}

## Kiwi Calls Found

```julia:./tableinput/gen #hideall
using CSV, DataFrames, DuckDB

function get_aggregate_X_calls(label::String)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/USB/AudioData.db")
  a=DBInterface.execute(con, "
    SELECT COUNT(*) AS Number_Calls,
      FROM pomona_labels_current
      WHERE $label = TRUE
    
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  return df.Number_Calls[1]
end

male = get_aggregate_X_calls("male")
female= get_aggregate_X_calls("female")
duets = get_aggregate_X_calls("duet")
total =  male + female + 2*duets

table = DataFrame("Call Type" => ["Solo Male", "Solo Female", "Duets", "Individual"],
                 "Number" => [male, female, duets, total])
CSV.write("./_assets/statistics/tableinput/aggregate_calls.csv", table)

```
\tableinput{}{statistics/tableinput/aggregate_calls.csv}

## Calls per Hour

```julia:./calls_per_hour.jl #hideall
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
```
### Aggregate Dataset

\output{./calls_per_hour.jl}

![Calls per Hour](/assets/statistics/calls_per_hour_aggregate.png)

\tableinput{}{statistics/tableinput/calls_per_hour_description.csv}

![Calls per Hour](/assets/statistics/calls_per_hour_frequency.png)

### By Time of Day

Hour is UTC, to get to NZ time add 12 or 13 hours. I need to work in UTC because turning the clock back in April causes havoc with my statistics.

![Calls per Hour](/assets/statistics/calls_per_hour.png)

### By Month

![Calls per Hour](/assets/statistics/calls_per_hour_by_month.png)

![Singing Kiwi](https://res.cloudinary.com/dofwwje6q/image/upload/v1657134405/Pomona/487DE791-C7FF-4144-81E0-7221B1BAA9AF_gmozib.jpg)


## Calls by Location

```julia:./tableinput/gen #hideall
using CSV, DataFrames, DuckDB

function get_calls_by_location()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/USB/AudioData.db")
  a=DBInterface.execute(con, "
    SELECT location AS Location, 
      SUM(CAST(male AS INT)) AS Solo_Male, 
      SUM(CAST(female AS INT)) AS Solo_Female, 
      SUM(CAST(duet AS INT)) AS Duets, 
      SUM(CAST(male AS INT)) + SUM(CAST(female AS INT)) + SUM(CAST(duet AS INT)) + SUM(CAST(duet AS INT)) AS Individual,
      SUM(CAST(not_kiwi AS INT)) AS False_Positives, 
      SUM(CAST(close_call AS INT)) AS Close,
      SUM(CAST(low_noise AS INT)) AS Low_Noise
      FROM pomona_labels_current
      GROUP BY location;  
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  return df
end
df=get_calls_by_location()
sort!(df, [:Individual], rev=[true])
push!(df, ["TOTAL", sum(df.Solo_Male), sum(df.Solo_Female), sum(df.Duets), sum(df.Individual), sum(df.False_Positives), sum(skipmissing(df.Close)), sum(skipmissing(df.Low_Noise))])
CSV.write("./_assets/statistics/tableinput/calls_by_location.csv", df)

```
\tableinput{}{statistics/tableinput/calls_by_location.csv}


