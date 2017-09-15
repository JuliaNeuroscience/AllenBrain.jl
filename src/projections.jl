function query_projection(id)
    rq = Requests.get("http://api.brain-map.org/api/v2/data/WellKnownFile/query.json?criteria=well_known_file_type[name\$eq'ImagesResampledTo25MicronARA'][attachable_id\$eq$id]")
    data = JSON.parse(String(rq.data))
    data["msg"][1]
end

"""
    download_projection(id, filename)

Download a volumetric image for a particular connectivity (projection)
dataset specified by its experiment `id` (available from the banner in
http://connectivity.brain-map.org/). Specify the `filename` used for
saving the dataset.
"""
function download_projection(id, filename)
    info = query_projection(id)
    download("http://api.brain-map.org"*info["download_link"], filename)
end
