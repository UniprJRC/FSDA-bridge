using Documenter
using FSDA

makedocs(
    sitename = "FSDAjl",
    authors  = "Group 3",
    modules  = [FSDA],
    warnonly = true,
    format   = Documenter.HTML(prettyurls = false),
    pages = [
        "Home" => "index.md",
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
