# function query(key::AbstractString, fieldname="acronym")
#     rq = HTTP.request("GET", "http://api.brain-map.org/api/v2/data/SectionDataSet/query.json?criteria=products[id\$eq1],genes[$fieldname\$eq'$key']&include=genes,section_images")
# end

const planedict = Dict("coronal"=>1, "sagittal"=>2)

function query_insitu(key::AbstractString; plane="coronal", fieldname="acronym")
    rq = HTTP.request("GET", "http://api.brain-map.org/api/v2/data/SectionDataSet/query.json?criteria=products[id\$eq1],genes[$fieldname\$eq'$key']&include=section_images,alignment3d,section_images(alignment2d)")
    data = JSON.parse(String(rq.data))
    planeid = planedict[plane]
    for sectiondataset in data["msg"]
        if sectiondataset["plane_of_section_id"] == planeid
            return sectiondataset
        end
    end
    error("No data found for $fieldname $key, section plane $plane")
end

function query_insitu(key::AbstractString, x, y, z; plane="coronal", fieldname="acronym")
    sectiondataset = query_insitu(key; plane=plane, fieldname=fieldname)
    query_reference2image(sectiondataset, x, y, z)
end

default_insitu_imagename(id) = "id"*lpad(string(id), 4, "0")*".jpg"

function download_insitu_images(genekey::AbstractString, bb::BoundingBox, dirname=genekey; plane="coronal", fieldname="acronym", downsample=0)
    @assert plane == "coronal"  # not tested yet for sagittal
    sectiondataset = query_insitu(genekey; plane=plane, fieldname=fieldname)
    download_insitu_images(sectiondataset, bb, dirname; downsample=downsample)
end

function download_insitu_images(sectiondataset::Dict, bb::BoundingBox, dirname; downsample=0)
    if !isdir(dirname)
        mkpath(dirname)
    end
    ids = [simg["id"] for simg in sectiondataset["section_images"]]  # ones for this gene
    res = sectiondataset["section_images"][1]["resolution"]*μm
    xmin, ymin, zmin = map(minimum, bb.intervals)
    xmax, ymax, zmax = map(maximum, bb.intervals)
    q = query_reference2image(sectiondataset, xmin, ymin, zmin)
    qmax = query_reference2image(sectiondataset, xmin, ymax, zmax)
    w, h = qmax["x"] - q["x"], qmax["y"] - q["y"]
    @show w h (ymax-ymin)/res (zmax-zmin)/res
    filenames = String[]
    processed = Int[]
    slicepos = Vector{NTuple{3,Float64}}(0)
    Δx = 50μm
    for x in xmin:Δx:xmax
        q = query_reference2image(sectiondataset, x, ymin, zmin)
        id = q["section_image_id"]
        id ∈ ids || continue
        id ∈ processed && continue
        fn = default_insitu_imagename(id)
        push!(filenames, fn)
        sectionimage(q, w, h, joinpath(dirname, fn); downsample=downsample)
        push!(processed, id)
        # Record the real-world slice position. (The slice may not be where we asked.)
        push!(slicepos, query_image2reference(id, q["x"], q["y"]))
    end
    # Also save data we'll use later in reconstructing the 3d space
    FileIO.save(joinpath(dirname, "metadata.jld2"),
                Dict("filenames"=>filenames,
                     "sectionposition"=>slicepos,
                     "downsample"=>downsample,
                     "sectiondataset"=>sectiondataset,
                     "boundingbox"=>bb))
end

    # showall(filenames)
    # showall(slicepos)
    # sz = imagesize(joinpath(dirname, filenames[1]))
    # for i = 2:length(filenames)
    #     sz = map(max, sz, imagesize(joinpath(dirname, filenames[i])))
    # end
    # img2d = load(joinpath(dirname, first(filenames)))
    # img = similar(img2d, sz[2], sz[1], length(filenames))
    # fill!(img, zero(eltype(img)))
    # for i = 1:length(filenames)
    #     fn = joinpath(dirname, filenames[i])
    #     if imagesize(fn) == sz
    #         img[:,:,i] = load(fn)
    #     end
    # end
    # resp = median(diff(slicepos))
    # FileIO.save(joinpath(dirname, "merged.nrrd"), AxisArray(img, (:P, :I, :R), (resp, res, res)))

# function download_insitu_images(genekey::AbstractString, x, y, dirname=genekey; plane="coronal", fieldname="acronym", downsample=0)
#     if !isdir(dirname)
#         mkpath(dirname)
#     end
#     sectiondataset = query_insitu(key; plane=plane, fieldname=fieldname)

#     sections = sectiondataset["section_images"]
#     cd(dirname) do
#         @showprogress 1 "Downloading images for $key: " for i = 1:length(sections)
#             id = sections[i]["id"]
#             download("http://api.brain-map.org/api/v2/image_download/$id?downsample=$downsample", default_insitu_imagename(id))
#         end
#         open("metadata.json", "w") do io
#             write(io, JSON.json(sectiondataset))
#         end
#     end
#     # TODO: how to handle downsample in the metadata? relevant for the alignment
#     nothing
# end

function assemble_insitu_images(dirname)
    cd(dirname) do
        sectiondataset = open("metadata.json") do io
            JSON.parse(io)
        end
        imgsinfo = sectiondataset["section_images"]
        aff3 = parse_3daffine(sectiondataset["alignment3d"])
        n = length(imgsinfo)
        local inds, ds
        img = Array{RGB{N0f8}}(map(length, inds)..., n)
        for (i, info) in enumerate(imgsinfo)
            id = info["id"]
            img2d = load(default_insitu_imagename(id))
            aff2 = parse_2daffine(info["alignment2d"])
            if i == 1
                ds = downsampling(img2d, info)
                inds = (1:500, 1:500)  # fixme
            end
            aff2s = scaletform(aff2, ds)
            img[:,:,i] = warp(img2d, inv(aff2s), inds)
        end
        img
    end
end

function downsampling(img, info::Dict)
    h, w = info["height"], info["width"]
    ih, iw = size(img)
    ph, pw = round(Int, log2(h/ih)), round(Int, log2(w/iw))
    @assert ph == pw
    ph
end

function scaletform(tform2, ds)
    f = 2.0^ds
    M = diagm([f,f,1])
    tfm = M\([tform2; [0 0 1]] * M)
    LinearMap(SMatrix{2, 2, Float64}(tfm[1:2,1:2])) ∘ Translation(tfm[1:2,3]...)
end

function parse_2daffine(dct::Dict)
    # section-to-volume = "tsv"
    # http://api.brain-map.org/doc/Alignment2d.html
    tsv = zeros(2,3)
    for j = 1:2, i = 1:2
        tsv[i,j] = dct["tsv_0"*string(sub2ind((2,2), j, i)-1)]  # row major
    end
    tsv[1,3] = dct["tsv_04"]
    tsv[2,3] = dct["tsv_05"]
    tsv
end

function parse_3daffine(dct::Dict)
    tvr = zeros(3,4)
    for j = 1:4, i = 1:3
        tvr[i,j] = dct["trv_"*lpad(string(sub2ind((3,4), i, j)-1), 2, "0")]
    end
    tvr
end
