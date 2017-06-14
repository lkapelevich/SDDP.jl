using Documenter, SDDP

makedocs(
    format = :html,
    sitename = "SDDP",
    pages = [
        "Introduction" => "index.md",
        "Tutorial" => "tutorial.md"
    ]
)

# deploydocs(
#     repo   = "github.com/odow/SDDP.jl.git",
#     target = "build",
#     osname = "linux",
#     julia  = "0.6",
#     deps   = nothing,
#     make   = nothing
# )
