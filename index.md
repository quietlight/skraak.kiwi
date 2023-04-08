@def title = "Skraak.kiwi"
#@def tags = ["home"]

# Pomona Audio Project

\tableofcontents <!-- you can use \toc as well -->

## Introduction

Night time audio data is recorded on Pomona Island with up to 18 Audio Moths. Haast Kiwi calls are found and monitored.

![Moth in anti-static bag](https://res.cloudinary.com/dofwwje6q/image/upload/w_400/v1647156108/Pomona/21D9D0DD-B925-4F46-B952-8FDF436E1FE2_nfqpv6.jpg)

## Workflow

```julia:./pomona_workflow.jl #hideall
run(`d2 -t 103 --sketch --pad 100 --center /Volumes/USB/new_skraak.kiwi/_assets/scripts/pomona_workflow.d2 /Volumes/USB/new_skraak.kiwi/_assets/pomona_workflow.svg`)
```
![Pomona Workflow](/assets/pomona_workflow.svg)

## Haast Tokoeka Are Endangered

![Haast Tokoeka on Rona Island](https://res.cloudinary.com/dofwwje6q/image/upload/w_400/v1647156142/Pomona/B8A96FD3-B6CA-4432-B9F7-47D4D4BBC1D8_zcmohx.jpg)

```julia:./pomona_why.jl #hideall
run(`d2 -t 104 --sketch --pad 100 --center /Volumes/USB/new_skraak.kiwi/_assets/scripts/pomona_why.d2 /Volumes/USB/new_skraak.kiwi/_assets/pomona_why.svg`)
```
![Pomona Why](/assets/pomona_why.svg)

<!--
## Trip Dates
* 2021-10-28 (boat)
* 2021-11-13 (kayak)
* 2021-11-25 (boat)
* 2021-12-18 (boat)
* 2022-01-17 (boat)
* 2022-02-12 (all 6 moths collected by volunteers)
* 2022-02-25 (boat/packraft, 18 moths placed)
* 2022-03-23 (N14 removed by mistake, batteries flat on 18th anyway)
* 2022-04-27 (bicycle, foot, packraft)
* 2022-05-27 (boat, 8 SD cards changed, 4 moths redeployed in new locations)
* 2022-06-18 (boat to Rona, packraft, foot, bike, 17 moths checked, 2 moths redeployed in new locations, 3 moths brought home, SD card from N14 corrupt and unrecoverable)
* 2022-08-27 (bicycle, foot, packraft, boat home after trap  check. 15 moths checked and 3 extra placed out.)
* 2022-10-08 (boat in and out thanks to Pomona Trust and Nick Key of Adventure Kayak and Cruise)
* 2022-12-17 (bicycle, foot, packraft, more packraft, boat, car, bicycle.)
* 2023-02-17 (bicycle, foot, packraft, foot, packraft, foot, bicycle.)
-->

![From Pomona Island](https://res.cloudinary.com/dofwwje6q/image/upload/w_800/v1647156097/Pomona/B7C51468-6BEE-4BDD-A295-C1E1021F0AF6_vnvb78.jpg)


## Current Locations

```julia:./current_locations.jl #hideall
#=import Pkg
Pkg.add("JSON3")
Pkg.add("VegaLite")
Pkg.add("VegaDatasets")=#
using DataFrames, DuckDB, JSON3, VegaLite, VegaDatasets
pomona_polygon = read("./_assets/pomona_polygon.json", String) |> JSON3.read
VV = VegaDatasets.VegaJSONDataset(pomona_polygon,"pomona_polygon.json")

function get_loc_list(l::Vector{String})::Vector{NamedTuple{(:latitude, :longitude, :name), Tuple{Float64, Float64, String}}}
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
moths=get_loc_list(["C05", "CB11", "D09", "F05", "F09", "G05", "H04", "M04", "N20", "NB14", "D05", "K09", "KS06", "N14", "NB5T", "S13T", "V05"])

# The db only knows location of already used spots, add new locations manually.
new_moths=[
  (latitude=-45.50075, longitude=167.48065, name="N10M")
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

for item in vcat(moths, new_moths)
  print("$(item.name)  ")
end
```

\output{./current_locations.jl}

![Current Audio Moth Locations](/assets/index/output/current_locations.png)

## Past Locations

```julia:./past_locations.jl #hideall
#=import Pkg
Pkg.add("DuckDB")
Pkg.add("DataFrames")=#

using DataFrames, DuckDB, JSON3, VegaLite, VegaDatasets
pomona_polygon = read("./_assets/pomona_polygon.json", String) |> JSON3.read
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

```

\output{./past_locations.jl}

![Past Audio Moth Locations](/assets/index/output/past_locations.png)

## Statistics

  * Aggregate statistics
  * Location statistics
  * [Old Notebook](/old-page), no longer maintained.

## Frequently Asked Questions

  * How often do Kiwi call?
  * When are Kiwi most vocal?
  * How long is a call?
  * How does vocalisation differ between sexes?
  * Are there many duets?
  * Does activity change with the weather?
  * Do rats bother Kiwi?
  * What does a baby Kiwi sound like?
  * How do the Pomona Kiwi compare with other Tokoeka populations?
  * Are there Kaka on Pomona?
  * How often do Kea visit Pomona?




