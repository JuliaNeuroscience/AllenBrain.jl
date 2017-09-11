function query_projection(id)
    rq = Requests.get("http://api.brain-map.org/api/v2/data/WellKnownFile/query.json?criteria=well_known_file_type[name\$eq'ImagesResampledTo25MicronARA'][attachable_id\$eq$id]")
    data = JSON.parse(String(rq.data))
    data["msg"][1]
end

function download_projection(id, filename)
    info = query_projection(id)
    download("http://api.brain-map.org"*info["download_link"], filename)
end
