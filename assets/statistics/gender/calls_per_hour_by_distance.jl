# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DataFramesMeta, DuckDB, Dates, Statistics, VegaLite

#close_call, ok_call, far_call
function get_calls_with_distance(distance::String)
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
    $distance = true;
  ")
  DBInterface.close!(con) 
  a=DataFrame(a) 
  return a
end

function get_files_night()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    file,
    time_bucket(INTERVAL '60 minutes', local_date_time) AS bucket
  FROM
    pomona_files
  WHERE
    night = true
  
  ")
  DBInterface.close!(con) 
  a=DataFrame(a)
  return a
end

function get_distance_calls_per_hour(distance::String)
  l=DataFrame(get_calls_with_distance("$distance"))
  #f=DataFrame(get_files_night())
  #df=leftjoin(l, f, on = :file)
  
  return levels(l.duet)
end

x=get_distance_calls_per_hour("close_call")
@info x