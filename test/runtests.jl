using Test

using AllocationViewer
using Profile.Allocs
using REPL.TerminalMenus: AbstractMenu, printmenu

@testset "filter" begin
    @test (@framefilter "@Test" && :iterate && !32) isa Function
    @test (@framefilter "runtests.jl":12:18 || Vector) isa Function
end

@testset "allocs_menu" begin
    f() = [rand(k) for k in 1:3]
    f()
    Allocs.@profile sample_rate = 1.0 f()
    Allocs.clear()
    Allocs.@profile sample_rate = 1.0 f()
    sf = Returns(true)
    m = AllocationViewer.allocs_menu(sf; pagesize = 10)
    @test m isa AbstractMenu
    buf = IOBuffer()
    @test printmenu(buf, m, 2; init = true) isa Int
end
