# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DuckDB, Markdown

function get_trips()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
  SELECT
    *
  FROM
    trip_reports
  ORDER BY
    trip_date DESC;
  ")
  DBInterface.close!(con)

  return a
end

df=get_trips() |> DataFrame

for row in eachrow(df)
	println("# $(row.trip_date)")
	println("
_To:_  $(row.destination)")
	println("
_How:_ ")
	println(row.how)
	println("
_Report:_ ")
	Markdown.parse(row.report) |> x -> println(x)
	println("")
	println("")
end