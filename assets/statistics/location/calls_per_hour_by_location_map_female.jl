# This file was generated, do not modify it. # hide
#hideall
using CSV, DataFrames, DataFramesMeta, DuckDB, JSON3, Statistics, VegaLite, VegaDatasets
pomona_polygon = read("./_assets/pomona_polygon.json", String) |> JSON3.read
VV = VegaDatasets.VegaJSONDataset(pomona_polygon,"pomona_polygon.json")

function get_loc_list()
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

  df2=DataFrame(CSV.File("_assets/statistics/tableinput/calls_per_hour_by_location.csv"))
  m=mean(df2.female)
  sd=std(df2.female)
  @transform!(df2, @byrow :colour = :female >= m ? "red" : (:female < m-sd ? "blue" : "orange"))
  df = innerjoin(df1, df2, on = :location)
  gdf = groupby(df, :colour)


  red = NamedTuple{(:latitude, :longitude, :name), Tuple{Float64, Float64, String}}[]
  orange = NamedTuple{(:latitude, :longitude, :name), Tuple{Float64, Float64, String}}[]
  blue = NamedTuple{(:latitude, :longitude, :name), Tuple{Float64, Float64, String}}[]
  for row in eachrow( gdf[(colour="red",)] )
     c =(latitude=row.lat, longitude=row.lon, name="$(row.location)")
     push!(red, c)
  end
  for row in eachrow( gdf[(colour="orange",)] )
     c =(latitude=row.lat, longitude=row.lon, name="$(row.location)")
     push!(orange, c)
  end
  for row in eachrow( gdf[(colour="blue",)] )
     c =(latitude=row.lat, longitude=row.lon, name="$(row.location)")
     push!(blue, c)
  end
  return red, orange, blue
end

red, orange, blue = get_loc_list()

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
    data=red,
    longitude="longitude:q",
    latitude="latitude:q",
    size={value=100},
    color={value=:red}
)+
@vlplot(
    :circle,
    data=orange,
    longitude="longitude:q",
    latitude="latitude:q",
    size={value=100},
    color={value=:orange}
)+
@vlplot(
    :circle,
    data=blue,
    longitude="longitude:q",
    latitude="latitude:q",
    size={value=100},
    color={value=:blue}
)

save("./_assets/statistics/calls_per_hour_by_location_map_female.png", X)