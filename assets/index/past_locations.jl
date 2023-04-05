# This file was generated, do not modify it. # hide
#hideall
#=import Pkg
Pkg.add("DuckDB")
Pkg.add("DataFrames")=#

using DataFrames, DuckDB, JSON3, VegaLite, VegaDatasets
pomona_polygon = read("./pomona_polygon.json", String) |> JSON3.read
VV = VegaDatasets.VegaJSONDataset(pomona_polygon,"pomona_polygon.json")

function get_loc_list()
  con = DBInterface.connect(DuckDB.DB, "/Volumes/USB/AudioData.db")
  a=DBInterface.execute(con, "
    SELECT location, 
      AVG(latitude) AS lat, 
      AVG(longitude)  AS lon,
      FROM pomona_files,
    GROUP BY location
    ORDER BY location ASC;
  ")
  DBInterface.close!(con)
  df=DataFrame(a)
  b=NamedTuple{(:latitude, :longitude, :name), Tuple{Float64, Float64, String}}[]
  for row in eachrow( df )
     c=(latitude=row.lat, longitude=row.lon, name="$(row.location)")
     push!(b, c)
  end
  return b
end

moths=get_loc_list()

X=@vlplot(width=455, height=500) +
@vlplot(
    mark={
        :geoshape,
        fill=:gray,
        stroke=:white
    },
    data={
        values=VV,
        format={
            typ=:topojson
        }
    },
   )+

@vlplot(
    :circle,
    data=moths,
    longitude="longitude:q",
    latitude="latitude:q",
    size={value=100},
    color={value=:black}
)

save(joinpath(@OUTPUT, "past_locations.png"), X)


for item in moths
  print("$(item.name)  ")
end