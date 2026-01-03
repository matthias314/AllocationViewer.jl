module AllocationViewer

export @track_allocs, @framefilter

using Base: Fix1
using Base.Filesystem: basename
using Base.Meta: isexpr
using Base.StackTraces: StackFrame
using InteractiveUtils: edit, @which
using Profile: short_path
using Profile.Allocs: Allocs, Alloc
using REPL.TerminalMenus: request
using StyledStrings

using FoldingTrees: TreeMenu, Node, fold!, setcurrent!, count_open_leaves
import FoldingTrees: writeoption

using StructEqualHash

struct Source
    file::Symbol
    line::Int
end

@struct_equal_hash Source

const colors = Iterators.cycle([:blue, :cyan, :green, :red, :magenta])

const pkgcolors = Iterators.Stateful(colors)
const pkgcolorcache = Dict{String, Any}("@julialib" => :shadow, "@juliasrc" => :shadow,
    "@Compiler" => :warning, string('@', @__MODULE__) => :error)

function coloredpkg(pkgname::String)
    color = get!(() -> popfirst!(pkgcolors), pkgcolorcache, pkgname)
    styled"{$color:$pkgname}"
end

const typecolors = Iterators.Stateful(colors)
const typecolorcache = Dict{Type, Any}()

function coloredtype(::Type{T}) where T
    color = get!(() -> popfirst!(typecolors), typecolorcache, T)
    styled"{$color:$T}"
end

const fncache = Dict{Symbol, Tuple{String,String,String}}()

fullpath(file::Symbol) = short_path(file, fncache)[1]
modstr(file::Symbol) = short_path(file, fncache)[2]

function relpath(file::Symbol)
    _, ms, rp = short_path(file, fncache)
    ms in ("@Base", "@Compiler") ? '/' * rp : rp
end

struct Colored
    obj::Any
end

function writeoption(io::IO, c::Colored, charsused::Int)
    writeoption(IOContext(io, :color => get(stdout, :color, false)), c.obj, charsused)
end

function writeoption(io::IO, (agroup, c, b)::Tuple{Source, Int, Int}, charsused::Int)
    ms, rp = modstr(agroup.file), relpath(agroup.file)
    writeoption(io, Colored(styled"$c allocs: $b bytes at $(coloredpkg(ms))$rp:$(agroup.line)"), charsused)
end

function writeoption(io::IO, a::Alloc, charsused::Int)
    writeoption(io, Colored(styled"$(a.size) bytes for $(coloredtype(a.type))"), charsused)
end

function writeoption(io::IO, sf::StackFrame, charsused::Int)
    ms, rp = modstr(sf.file), relpath(sf.file)
    writeoption(io, Colored(styled"$(coloredpkg(ms))$rp:$(sf.line) $(sf.func)"), charsused)
end

framefilter(f) = f
framefilter(::Nothing) = (a, sf) -> !(modstr(sf.file) in ("", "@julialib", "@juliasrc"))
framefilter(s::Symbol) = (a, sf) -> sf.func == s
framefilter(::Type{T}) where T = (a, sf) -> framefilter(nothing)(a, sf) && a.type <: T
framefilter(r::Regex) = (a, sf) -> match(r, String(sf.file)) !== nothing

function framefilter(s::AbstractString)
    if s == "@"
        (a, sf) -> !(modstr(sf.file) in ("", "@julialib", "@juliasrc", "@Base"))
    elseif s[1] == '@'
        (a, sf) -> modstr(sf.file) == s
    else
        (a, sf) -> basename(String(sf.file)) == s
    end
end

function framefilter(::Type{T}, c::Union{Integer, AbstractVector{<:Integer}, AbstractSet{<:Integer}}) where T
    (a, sf) -> framefilter(T)(a, sf) && a.size in c
end

function framefilter(s::Union{AbstractString, Regex}, c::Union{Integer, AbstractVector{<:Integer}, AbstractSet{<:Integer}})
    (a, sf) -> framefilter(s)(a, sf) && sf.line in c
end

framefilter(x, i::Integer, j::Integer) = framefilter(x, i:j)

const bottomfilter = framefilter(string('@', @__MODULE__))

function parsefilter(ex)
    if isexpr(ex, :||)
        parsedargs = map(parsefilter, ex.args)
        :((a, sf) -> any(f -> f(a, sf), [$(parsedargs...)] ))
    elseif isexpr(ex, :&&)
        parsedargs = map(parsefilter, ex.args)
        :((a, sf) -> all(f -> f(a, sf), [$(parsedargs...)] ))
    elseif isexpr(ex, :call, 2) && ex.args[1] == :!
        :((a, sf) -> framefilter(nothing)(a, sf) && !$(parsefilter(ex.args[2]))(a, sf))
    elseif isexpr(ex, :call) && ex.args[1] == :(:)
        Expr(:call, framefilter, esc.(ex.args[2:end])...)
    else
        Expr(:call, framefilter, esc(ex))
    end
end

macro framefilter(ex)
    parsefilter(ex)
end

function addframes!(sffilter::SF, alloc_node) where SF
    a::Alloc = alloc_node.data
    empty!(alloc_node.children)
    i = findfirst(Fix1(sffilter, a), a.stacktrace)::Int
    j = if sffilter != Returns(true)
        # findnext((a, sf) -> sf.line == -1 || bottomfilter(a, sf), a.stacktrace, i)
        findnext(Fix1(bottomfilter, a), a.stacktrace, i)::Int
    else
        length(a.stacktrace)+1
    end
    foreach(sf -> Node(sf, alloc_node), @view a.stacktrace[i:j-1])
end

if VERSION >= v"1.13-"
    lastcmd() = Base.active_repl.mistate.current_mode.hist.history[end].content
else
    lastcmd() = Base.active_repl.mistate.current_mode.hist.history[end]
end

function allocs_menu(sffilter::SF, res = Allocs.fetch()) where SF

    function keypress(menu::TreeMenu, i::UInt32)
        setcurrent!(menu, menu.cursoridx)
        node = menu.current
        data = node.data
        if i == Int('e')
            if data isa Alloc
                data = node.parent.data::Tuple{Source,Int,Int}
            end
            if data isa Tuple{Source, Int, Int}
                data = first(data)
            end
            @assert data isa Union{Source, StackFrame}
            edit(fullpath(data.file), data.line)
        elseif i == Int('f') && data isa Alloc
            addframes!(sffilter, node)
        elseif i == Int('r') && data isa Alloc
            addframes!(framefilter(nothing), node)
        elseif i == Int('R') && data isa Alloc
            addframes!(Returns(true), node)
        end
        menu.pagesize = min(menu.maxsize, count_open_leaves(menu.root))
        false
    end

    allocs = res.allocs
    agroups = Dict{Source,Vector{Alloc}}()
    sc = sb = 0
    for a in allocs
        i = findfirst(Fix1(sffilter, a), a.stacktrace)
        if i !== nothing && bottomfilter(a, a.stacktrace[i])
            i = nothing
        end
        if i !== nothing
            sf = a.stacktrace[i]
            agroup = Source(sf.file, sf.line)
            as = get!(() -> Alloc[], agroups, agroup)
            push!(as, a)
        else
            sc += 1
            sb += a.size
        end
    end

    empty!(fncache)
    root = Node{Any}(missing)
    fb = fc = 0
    for (agroup, as) in agroups
        b = sum(a -> a.size, as)
        fb += b
        fc += length(as)
        agroup_node = Node((agroup, length(as), b), root)
        for alloc in as
            alloc_node = Node(alloc, agroup_node)
            addframes!(sffilter, alloc_node)
            fold!(alloc_node)
        end
        fold!(agroup_node)
    end
    header = styled"$fc allocs: $fb bytes at $(length(agroups)) source locations"
    if sc > 0
        header *= styled" {shadow:(ignoring $sc allocs: $sb bytes)}"
    end
    root.data = Colored(header)
    height, _ = displaysize(stdout)
    cmdlines = countlines(IOBuffer(lastcmd()))
    pagesize = max(height-cmdlines, trunc(Int, 0.75*height))
    TreeMenu(root; pagesize, dynamic = true, keypress)
end

macro track_allocs(ex, sffilterex = nothing)
    vars = Expr(:block)

    function traverse(ex)
        if !(ex isa Expr)
            ex
        elseif ex.head == :$
            var = gensym()
            push!(vars.args, Expr(:(=), esc(var), esc(only(ex.args))))
            var
        else
            Expr(ex.head, traverse.(ex.args)...)
        end
    end

    sffilter = parsefilter(sffilterex)
    body = quote
        f() = ($(esc(traverse(ex))); nothing)
        # warming up f and profiling code
        f() # precompile(f, ())
        Allocs.@profile $(esc(:sample_rate)) = 1.0 nothing
        Allocs.clear()
        # @info "profiling start"
        Allocs.@profile $(esc(:sample_rate)) = 1.0 f()
        # @info "profiling stop"
        request(allocs_menu($sffilter); cursor = 2)
        nothing
    end
    Expr(:let, vars, body)
end

end
