using AWSS3
using AWSS3: AWSConfig

const allen_config = AWSConfig(; creds=nothing, region="us-west-2")

# Create a few types that allow JSON3 to parse the manifest.json file
struct AWSDir
    relative_path::String
    version::String
    total_size::Int
    url::String
    view_link::String
end
Base.show(io::IO, d::AWSDir) = print(io, "AWSDir(\"", d.relative_path, "\", size=", d.total_size, ")")

struct AWSDirs
    directories::Dict{String,AWSDir}
end
Base.show(io::IO, d::AWSDirs) = print(io, [k => d for (k, d) in d.directories])
Base.getindex(d::AWSDirs, k) = d.directories[k]
Base.iterate(d::AWSDirs) = iterate(d.directories)
Base.iterate(d::AWSDirs, i) = iterate(d.directories, i)

struct AWSManifest
    resource_uri::String
    version::String
    directory_listing::Dict{String,AWSDirs}
    file_listing::Dict{String,Any}
end
Base.show(io::IO, manifest::AWSManifest) = print(io, "AWSManifest(version = \"", manifest.version,
    "\", length(directory_listing) = ", length(manifest.directory_listing),
    ", length(file_listing) = ", length(manifest.file_listing), ")")

StructTypes.StructType(::Type{AWSDir}) = StructTypes.Struct()
StructTypes.StructType(::Type{AWSDirs}) = StructTypes.Struct()
StructTypes.StructType(::Type{AWSManifest}) = StructTypes.Struct()

function awsmanifest(version)
    url = "https://allen-brain-cell-atlas.s3-us-west-2.amazonaws.com/releases/$version/manifest.json"
    rq = HTTP.request("GET", url)
    return JSON3.read(String(rq.body), AWSManifest)
end

bucket(manifest::AWSManifest) = startswith(manifest.resource_uri, "s3://") ? split(manifest.resource_uri, "/")[3] : error("Not an S3 URI: ", manifest.resource_uri)

function download_dir(manifest::AWSManifest, dir::AWSDir, to::AbstractString; config=allen_config)
    from = S3Path(manifest.resource_uri * dir.relative_path; config)
    @show from to
    sync(from, to)
end

function download_dirs(f, manifest::AWSManifest, to)
    if !isdir(to)
        mkpath(to)
    end
    for (relpath, contents) in manifest.directory_listing
        for (name, dir) in contents
            f(name) || continue
            download_dir(manifest, dir, joinpath(to, relpath))
        end
    end
end
download_metadatas(manifest::AWSManifest, to) = download_dirs(x -> x == "metadata", manifest, to)

