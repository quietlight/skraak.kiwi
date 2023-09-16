# This file was generated, do not modify it. # hide
#hideall
#=import Pkg
Pkg.add("JSON3")
Pkg.add("VegaLite")
Pkg.add("VegaDatasets")=#
using DataFrames, DuckDB, JSON3, VegaLite, VegaDatasets
pomona_polygon = read("./_assets/pomona_polygon.json", String) |> JSON3.read
VV = VegaDatasets.VegaJSONDataset(pomona_polygon,"pomona_polygon.json")

function get_loc_list(l::Vector{String})::Vector{NamedTuple{(:latitude, :longitude, :name), Tuple{Float64, Float64, String}}}
  con = DBInterface.connect(DuckDB.DB, "/Volumes/SSD1/AudioData.duckdb")
  a=DBInterface.execute(con, "
    SELECT location,
      AVG(latitude) AS lat,
      AVG(longitude)  AS lon,
      FROM pomona_files,
    GROUP BY location
    ORDER BY location ASC;
  ")
  DBInterface.close!(con)
  df1=DataFrame(a)
  df2=filter(row -> row.location in l, df1)
  b=NamedTuple{(:latitude, :longitude, :name), Tuple{Float64, Float64, String}}[]
  for row in eachrow(df2)
     c=(latitude=row.lat, longitude=row.lon, name="$(row.location)")
     push!(b, c)
  end
  return b
end

# List of locations, known by db already.
moths=get_loc_list(["C05", "D03", "D09", "F09", "G05", "H04", "M04", "N14", "N20", "NB14", "A11", "H09", "CB11", "S13T", "N08M"])

# The db only knows location of already used spots, add new locations manually.
# new_moths=[(latitude=-45.50075, longitude=167.48065, name="N10M")]
new_moths=[
    (latitude=-45.51609, longitude=167.4715, name="W20"),
    (latitude=-45.51419, longitude=167.46801, name="J06"),
    (latitude=-45.51053, longitude=167.47281, name="S23"),
    (latitude=-45.50292, longitude=167.46212, name="W04"),
    (latitude=-45.50127, longitude=167.46917, name="V04")
    ]


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
    color={value=:brown}
)+
@vlplot(
    :circle,
    data=new_moths,
    longitude="longitude:q",
    latitude="latitude:q",
    size={value=100},
    color={value=:brown}
)


#save("current_locations.png", X)
save(joinpath(@OUTPUT, "current_locations.png"), X)

#for item in vcat(moths, new_moths)
for item in vcat(moths)
  print("$(item.name)  ")
end