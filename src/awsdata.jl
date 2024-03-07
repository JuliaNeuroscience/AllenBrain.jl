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

"""
    download_dir(manifest, relative_path, to; [config])

Download Allen Brain data form `manifest.resource_uri * relative_path` to `to`.

# Positional arguments:

- `manifest`: Allen Brain manifest data

    You can get with call `version = "20231215"; manifest = awsmanifest(version)`.

- `relative_path`: Relative path of the data you want to download. Full path will be constructed with `manifest.resource_uri * relative_path`.

- `to` : Download path and file name

# Keyword arguments:

- `config`: configuratoin to connect Allen Brain dataset location in AWS.


# Examples
To download data with feature_matrix_label = "WMB-10Xv2-TH" which is in dataset_label="WMB-10Xv2"

```jldoctest

julia> expression_matrices = manifest.file_listing["WMB-10Xv2"]["expression_matrices"]

Dict{String, Any} with 10 entries:

  "WMB-10Xv2-OLF"         => Dict{String, Any}("raw"=>Dict{String, Any}("files"=>Dict{String, Any}("h5ad"=>Dict{String, Any}("relative_path"=>"expression_matrices/WMB-10Xv2/2…

  ...

  "WMB-10Xv2-Isocortex-4" => Dict{String, Any}("raw"=>Dict{String, Any}("files"=>Dict{String, Any}("h5ad"=>Dict{String, Any}("relative_path"=>"expression_matrices/WMB-10Xv2/2…

julia> feature_matrix_label = "WMB-10Xv2-TH"

"WMB-10Xv2-TH"

julia> rpath = expression_matrices[feature_matrix_label]["log2"]["files"]["h5ad"]["relative_path"]
                                                       # for raw data, use "raw" instead of "log2"

"expression_matrices/WMB-10Xv2/20230630/WMB-10Xv2-TH-log2.h5ad"

julia> download_base = joinpath(datapath,"AllenBrain")

"/storage1/fs1/holy/Active/username/work/Data/AllenBrain"

julia> local_path = joinpath(download_base, split(rpath,"/")... )

"/storage1/fs1/holy/Active/username/work/Data/AllenBrain/expression_matrices/WMB-10Xv2/20230630/WMB-10Xv2-TH-log2.h5ad"

julia> AllenBrain.download_dir(manifest, rpath, local_path)

from = p"s3://allen-brain-cell-atlas/expression_matrices/WMB-10Xv2/20230630/WMB-10Xv2-TH-log2.h5ad"

to = "/storage1/fs1/holy/Active/username/work/Data/AllenBrain/expression_matrices/WMB-10Xv2/20230630/WMB-10Xv2-TH-log2.h5ad"

```
"""
function download_dir(manifest::AWSManifest, relative_path::String, to::AbstractString; config=allen_config)
    from = S3Path(manifest.resource_uri * relative_path; config)
    @show from to
    pt, _ = splitdir(to)
    isdir(pt) || mkdir(Path(pt), recursive=true, exist_ok=true)
    sync(from, Path(to))
end
