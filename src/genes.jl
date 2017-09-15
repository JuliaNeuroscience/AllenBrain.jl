function query(key::AbstractString, fieldname="acronym")
    rq = Requests.get("http://api.brain-map.org/api/v2/data/SectionDataSet/query.json?criteria=products[id\$eq1],genes[$fieldname\$eq'$key']&include=genes,section_images")
end

const planedict = Dict("coronal"=>1, "sagittal"=>2)

function query_insitu(key::AbstractString; plane="coronal", fieldname="acronym")
    rq = Requests.get("http://api.brain-map.org/api/v2/data/SectionDataSet/query.json?criteria=products[id\$eq1],genes[$fieldname\$eq'$key']&include=section_images,alignment3d,section_images(alignment2d)")
    data = JSON.parse(String(rq.data))
    planeid = planedict[plane]
    for sectiondata in data["msg"]
        if sectiondata["plane_of_section_id"] == planeid
            return sectiondata
        end
    end
    error("No data found for $fieldname $key, section plane $plane")
end

default_insitu_imagename(id) = "id"*lpad(string(id), 4, "0")

function download_insitu_images(key::AbstractString, dirname; plane="coronal", fieldname="acronym", downsample=0)
    if !isdir(dirname)
        mkpath(dirname)
    end
    sectionimageinfo = query_insitu(key; plane=plane, fieldname=fieldname)
    cd(dirname) do
        for i = 1:length(imgs)
            id = sectionimageinfo[1]["id"]
            download("http://api.brain-map.org/api/v2/image_download/$id?downsample=$downsample&view=expression", default_insitu_imagename(id))
        end
        open("metadata.json", "w") do io
            write(io, JSON.json(sectionimageinfo))
        end
    end
    # TODO: how to handle downsample in the metadata? relevant for the alignment
    nothing
end

function assemble_insitu_images(dirname)
    cd(dirname) do

    end
end
