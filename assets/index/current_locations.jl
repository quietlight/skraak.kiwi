# This file was generated, do not modify it. # hide
#hideall

#=import Pkg
Pkg.add("JSON3")
Pkg.add("VegaLite")
Pkg.add("VegaDatasets")=#
using JSON3, VegaLite, VegaDatasets
pomona_polygon = read("pomona_polygon.json", String) |> JSON3.read
VV = VegaDatasets.VegaJSONDataset(pomona_polygon,"pomona_polygon.json")
micro_moths=[
  (latitude=-45.50608, longitude=167.47822, name="C05"),
  #(latitude=-45.50368, longitude=167.47839, name="D03"),
  (latitude=-45.50898, longitude=167.47497, name="CB11"),
  (latitude=-45.50471, longitude=167.46985, name="D09"),
  #(latitude=-45.50885, longitude=167.47606, name="E07"),
  (latitude=-45.50602, longitude=167.47055, name="F05"), #could be wrong
  (latitude=-45.50603, longitude=167.47371, name="F09"),
  (latitude=-45.50866, longitude=167.46894, name="G05"),
  (latitude=-45.50827, longitude=167.46526, name="H04"),
  #(latitude=-45.51814, longitude=167.47226, name="J11"),
  (latitude=-45.50211, longitude=167.46574, name="M04"),
  (latitude=-45.49977, longitude=167.47078, name="N20"),
  (latitude=-45.50359, longitude=167.46855, name="NB14")
  #(latitude=-45.50881, longitude=167.47052, name="WD05")
]
moths=[
  #(latitude=-45.50989, longitude=167.47869, name="A11"),
  #(latitude=-45.51379, longitude=167.47322, name="H15"),
  (latitude=-45.50444, longitude=167.47352, name="D05"),
  (latitude=-45.50574, longitude=167.46245, name="Junction"),
  (latitude=-45.50249, longitude=167.46228, name="KS06"),
  (latitude=-45.50075, longitude=167.48065, name="N10M"),
  (latitude=-45.50121, longitude=167.47632, name="N14"),
  (latitude=-45.50300, longitude=167.47707, name="NB5T"),
  (latitude=-45.50540, longitude=167.46642, name="S13T"),
  #(latitude=-45.50025, longitude=167.46834, name="T10"),
  (latitude=-45.50162, longitude=167.47020, name="V05"),
  #(latitude=-45.50213, longitude=167.46643, name="V23")
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
    data=micro_moths,
    longitude="longitude:q",
    latitude="latitude:q",
    size={value=100},
    color={value=:brown}
)+
@vlplot(
    :circle,
    data=moths,
    longitude="longitude:q",
    latitude="latitude:q",
    size={value=100},
    color={value=:brown}
)

#save("current_locations.png", X)
save(joinpath(@OUTPUT, "current_locations.png"), X)

for item in micro_moths
  print("$(item.name)  ")
end
println("\n   ")

for item in moths
  print("$(item.name)  ")
end