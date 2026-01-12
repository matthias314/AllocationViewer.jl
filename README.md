# AllocationViewer.jl

The aim of this package is to provide a way to examine allocation profiles in Julia
that is more user-friendly than the built-in function
[`Profile.Allocs.print`](https://docs.julialang.org/en/v1/stdlib/Profile/#Profile.Allocs.print),
but at the same time much more lightweight than the graphical solutions
[ProfileCanvas.jl](https://github.com/pfitzseb/ProfileCanvas.jl)
and
[PProf.jl](https://github.com/JuliaPerf/PProf.jl),
which install more than 100 MB (ProfileCanvas.jl) or 300 MB (PProf.jl) of software.

Alocations can be filtered by type and size as well as source location (package, file and line number)
and function name of a stack frame. They are displayed in collapsible menus as provided by
[FoldingTrees.jl](https://github.com/JuliaCollections/FoldingTrees.jl).
Pressing the space bar on a menu item expands or collapses that item.
Pressing `'e'` on a line mentioning a source location open an editor at that line;
`'q'` quits the menu.

See the docstrings for `@track_allocs` and `@framefilter` for more details.

## Example

Here we investigate allocations that happen in `iterate` methods defined
in the packacke Combinatorics.jl and are not of type `Memory`:
```
julia> using AllocationViewer, Combinatorics

julia> @track_allocs sum(permutations(1:3)) "@Combinatorics" && :iterate && !Memory
     33 allocs: 1296 bytes at 3 source locations (ignoring 39 allocs: 1544 bytes)
   +  12 allocs: 576 bytes at @Combinatorics/src/permutations.jl:37 iterate
      9 allocs: 336 bytes at @Combinatorics/src/permutations.jl:28 iterate
   +   32 bytes for Vector{Int64}
   +   32 bytes for Vector{Int64}
       80 bytes for Dict{Int64, Nothing}
 >      @Combinatorics/src/permutations.jl:28 iterate
        @Combinatorics/src/permutations.jl:27 iterate
        @Base/reduce.jl:48 _foldl_impl
        @Base/reduce.jl:40 foldl_impl
        @Base/reduce.jl:36 mapfoldl_impl
        @Base/reduce.jl:167 #mapfoldl#270
        @Base/reduce.jl:167 mapfoldl
        @Base/reduce.jl:299 #mapreduce#274
        @Base/reduce.jl:299 mapreduce
        @Base/reduce.jl:524 #sum#277
        @Base/reduce.jl:524 sum
        @Base/reduce.jl:553 #sum#278
        @Base/reduce.jl:553 sum
   +   32 bytes for Vector{Int64}
   +   32 bytes for Vector{Int64}
   +   32 bytes for Vector{Vector{Int64}}
   +   32 bytes for Vector{Int64}
   +   32 bytes for Vector{Int64}
   +   32 bytes for Vector{Int64}
   +  12 allocs: 384 bytes at @Combinatorics/src/permutations.jl:287 iterate
```
