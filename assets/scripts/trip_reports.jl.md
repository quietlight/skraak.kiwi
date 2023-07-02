
```julia:./trip_reports.jl #hideall
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
	println("When: $(row.trip_date)")
	println("Where: $(row.destination)")
	println("How:")
	println(row.how)
	println("Report:")
	Markdown.parse(row.report) |> x -> @info x
	println("")
	println("")
end
```