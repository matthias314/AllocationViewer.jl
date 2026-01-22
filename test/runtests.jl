using Test

using AllocationViewer
using Base.Filesystem: mktemp
using Profile: Allocs, slash

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

@testset "@track_allocs" begin
    down = "\e[B"
    mktemp() do _, io
        print(io, " $(down) rRfq")
        seek(io, 0)
        @test nothing === redirect_stdio(stdin = io, stdout = devnull) do
            @track_allocs pagesize = 100 [rand(k) for k in 1:3] !Memory
        end
        seek(io, 0)
        @test nothing === redirect_stdio(stdin = io, stdout = devnull) do
            @track_allocs sample_rate = 0.5 [rand(k) for k in 1:3]
        end
    end
end
