# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DuckDB

function get_aggregate_X_calls(label::String)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
    SELECT COUNT(*) AS Number_Calls,
      FROM tuning_fork_labels_20230907
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
CSV.write("./_assets/statistics/tableinput/haast_aggregate_calls.csv", table )