# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DuckDB

function get_aggregate_X_calls(label::String)
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
    SELECT COUNT(*) AS Number_Calls,
      FROM pomona_labels_20230418
      WHERE $label = TRUE
    
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  return df.Number_Calls[1]
end

duets = get_aggregate_X_calls("duet")
male = get_aggregate_X_calls("male")
female= get_aggregate_X_calls("female")
total = 2*duets + male + female
male_percent = round(((male + duets) / total * 100); digits=2)
female_percent = round(((female + duets) / total * 100); digits=2)

table = DataFrame("" => ["Male", "Female"],
                 "Number" => [(male + duets), (female + duets)],
                 "Percent" => [male_percent, female_percent])
CSV.write("./_assets/statistics/tableinput/gender_calls.csv", table)