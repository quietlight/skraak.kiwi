# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DuckDB

function get_calls_by_location()
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
      FROM tuning_fork_labels_20230907
      GROUP BY location;  
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  return df
end
df=get_calls_by_location()
sort!(df, [:Individual], rev=[true])
push!(df, ["TOTAL", sum(df.Solo_Male), sum(df.Solo_Female), sum(df.Duets), sum(df.Individual), sum(df.False_Positives), sum(skipmissing(df.Close)), sum(skipmissing(df.Low_Noise))])
CSV.write("./_assets/statistics/tableinput/haast_calls_by_location.csv", df)