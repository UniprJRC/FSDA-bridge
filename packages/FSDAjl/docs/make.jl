using Documenter
using FSDABridge

makedocs(
    sitename = "FSDABridge.jl",
    authors  = "UniprJRC",
    modules  = [FSDABridge],
    format   = Documenter.HTML(prettyurls = false),
    pages = [
        "Home" => "index.md",
        "API reference" => "api.md",
        "Examples" => [
            "mahalFS"  => "examples/mahalfs.md",
            "unibiv"   => "examples/unibiv.md",
            "mcd"      => "examples/mcd.md",
            "FSM"      => "examples/fsm.md",
            "FSMeda"   => "examples/fsmeda.md",
            "LXS"      => "examples/lxs.md",
            "MMreg"    => "examples/mmreg.md",
            "FSR"      => "examples/fsr.md",
            "FSRaddt"  => "examples/fsraddt.md",
            "Score"    => "examples/score.md",
            "FSRfan"   => "examples/fsrfan.md",
            "tclust"   => "examples/tclust.md",
            "tkmeans"  => "examples/tkmeans.md",
        ],
    ],
)
