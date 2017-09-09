using Requests, JSON

const mousedir = joinpath(dirname(@__DIR__), "data", "mouse")
if !isdir(mousedir)
    mkpath(mousedir)
end

sg = joinpath(mousedir, "structure_graph.json")
if !isfile(sg)
    rq = Requests.get("http://api.brain-map.org/api/v2/structure_graph_download/1.json")
    data = JSON.parse(String(rq.data))
    hierarchy = data["msg"][1]

    open(sg, "w") do io
        write(io, JSON.json(hierarchy))
    end
end
