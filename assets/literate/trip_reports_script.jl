# This file was generated, do not modify it.

using CSV, DataFrames, DuckDB

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
	println(row.report)
	println("")
	println("")
end

x = exp(im*π) + 1

x ≈ 0

abs(x) < eps()

md"""
#### Conclusion

The equation $ \exp(i\pi) + 1 \quad = \quad 0 $ is proven thanks to our very rigorous proof.
"""

