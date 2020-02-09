using HTTP, JSON

const mousedir = joinpath(dirname(@__DIR__), "data", "mouse")
if !isdir(mousedir)
    mkpath(mousedir)
end

sg = joinpath(mousedir, "structure_graph.json")
genes = joinpath(mousedir, "genes.json")

if !isfile(sg)
    rq = HTTP.request("GET", "http://api.brain-map.org/api/v2/structure_graph_download/1.json")
    data = JSON.parse(String(rq.data))
    hierarchy = data["msg"][1]

    open(sg, "w") do io
        write(io, JSON.json(hierarchy))
    end
end

if !isfile(genes)
    info("Downloading genes database. This will take a while, but only needs to be done once.")
    rq = HTTP.request("GET", "http://api.brain-map.org/api/v2/data/Gene/query.json?criteria=products[id\$eq1]"; query=Dict("num_rows"=>19991))
    data = JSON.parse(String(rq.data))
    g = data["msg"]
    open(genes, "w") do io
        write(io, JSON.json(g))
    end
end
