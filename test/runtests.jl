using Test

using AllocationViewer
using FoldingTrees: TreeMenu, nodes, unfold!
using Profile: Allocs, slash
using REPL.TerminalMenus: printmenu

@testset "filter" begin
    @test (@framefilter "@Test" && :iterate && !32) isa Function
    @test (@framefilter "runtests.jl":12:18 || Vector) isa Function
end

@testset "paths" begin
    file = Symbol(pathof(AllocationViewer))
    @test AllocationViewer.fullpath(file) == pathof(AllocationViewer)
    @test AllocationViewer.modstr(file) == "@AllocationViewer"
    @test AllocationViewer.relpath(file) == slash * joinpath("src", "AllocationViewer.jl")
end

@testset "allocs_menu" begin
    f() = [rand(k) for k in 1:3]
    f()
    Allocs.@profile sample_rate = 1.0 f()
    Allocs.clear()
    Allocs.@profile sample_rate = 1.0 f()
    sf = Returns(true)

    root = AllocationViewer.allocs_tree(sf, Allocs.fetch())
    foreach(unfold!, nodes(root))
    menu = TreeMenu(root; pagesize = 100)
    @test printmenu(IOBuffer(), menu, 2; init = true) isa Int

    menu = AllocationViewer.allocs_menu(sf; pagesize = 10)
    @test menu isa TreeMenu
end
