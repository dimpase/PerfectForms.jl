using Documenter, PerfectForms

makedocs(
    sitename="PerfectForms.jl",
    modules=[PerfectForms],
    checkdocs=:exports,
    format=Documenter.HTML(prettyurls=true, edit_link="main"),
    pages=[
        "Home" => "index.md",
        "Installation" => "installation.md",
        "Usage" => "usage.md",
        "Backend configuration" => "configuration.md",
        "Development" => "development.md",
        "API reference" => "api.md",
    ],
)

if get(ENV, "DOCUMENTER_DEPLOY", "false") == "true"
    deploydocs(repo="github.com/dimpase/PerfectForms.jl.git", devbranch="main")
end
