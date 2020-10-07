"""
    lazy_map(f,a::AbstractArray...) -> AbstractArray

Applies the `Mapping` (or `Function`) `f` to the entries of the arrays in `a`
(see the definition of [`Mapping`](@ref)).

The resulting array `r` is such that `r[i]` equals to `evaluate(f,ai...)` where `ai`
is the tuple containing the `i`-th entry of the arrays in `a` (see function
[`evaluate`](@ref) for more details).
In other words, the resulting array is numerically equivalent to:

    map( (x...)->evaluate(f,x...), a...)

# Examples

Using a function as mapping

```jldoctest
using Gridap.Arrays

a = collect(0:5)
b = collect(10:15)

c = lazy_map(+,a,b)

println(c)

# output
[10, 12, 14, 16, 18, 20]
```

Using a user-defined mapping

```jldoctest
using Gridap.Arrays
import Gridap.Arrays: evaluate!

a = collect(0:5)
b = collect(10:15)

struct MySum <: Mapping end

evaluate!(cache,::MySum,x,y) = x + y

k = MySum()

c = lazy_map(k,a,b)

println(c)

# output
[10, 12, 14, 16, 18, 20]
```
"""
@inline function lazy_map(k,f::AbstractArray...)
  s = common_size(f...)
  lazy_map(evaluate,Fill(k, s...), f...)
end

@inline lazy_map(::typeof(evaluate),k::AbstractArray,f::AbstractArray...) = LazyArray(k,f...)

"""
    lazy_map(::Type{T},f,a::AbstractArray...) where T

Like [`lazy_map(f,a::AbstractArray...)`](@ref), but the user provides the element type
of the resulting array in order to circumvent type inference.
"""
@inline function lazy_map(k,T::Type,f::AbstractArray...)
  s = common_size(f...)
  lazy_map(evaluate,T,Fill(k, s...), f...)
end

@inline lazy_map(::typeof(evaluate),T::Type,k::AbstractArray,f::AbstractArray...) = LazyArray(T,k,f...)

# """
#     lazy_map(f::AbstractArray,a::AbstractArray...) -> AbstractArray
# Applies the mappings in the array of mappings `f` to the entries in the arrays in `a`.

# The resulting array has the same entries as the one obtained with:

#     map( lazy_map, f, a...)

# See the [`evaluate`](@ref) function for details.

# # Example

# "Evaluating" an array of functions

# ```jldoctest
# using Gridap.Arrays

# f = [+,-,max,min]
# a = [1,2,3,4]
# b = [4,3,2,1]

# c = lazy_map(f,a,b)

# println(c)

# # output
# [5, -1, 3, 1]
# ```
# """
# function lazy_map(g::AbstractArray,f::AbstractArray...)
#   LazyArray(g,f...)
# end

# """
#     lazy_map(::Type{T},f::AbstractArray,a::AbstractArray...) where T

# Like [`lazy_map(f::AbstractArray,a::AbstractArray...)`](@ref), but the user provides the element type
# of the resulting array in order to circumvent type inference.
# """
# function lazy_map(::Type{T},g::AbstractArray,f::AbstractArray...) where T
#   LazyArray(T,g,f...)
# end

# function _lazy_map_mapping(k,f::AbstractArray...)
#     s = common_size(f...)
#     lazy_map(Fill(k, s...), f...)
# end

# function _lazy_map_mapping(::Type{T},k,f::AbstractArray...) where T
#   s = common_size(f...)
#   lazy_map(T,Fill(k, s...), f...)
# end


"""
Subtype of `AbstractArray` which is the result of `lazy_map`. It represents the
result of lazy_maping a mapping / array of mappings to a set of arrays that
contain the mapping arguments. This struct makes use of the cache provided
by the mapping in order to compute its indices (thus allowing to prevent
allocation). The array is lazy, i.e., the values are only computed on
demand. It extends the `AbstractArray` API with two methods:

   `array_cache(a::AbstractArray)`
   `getindex!(a::AbstractArray,i...)`
"""
struct LazyArray{G,T,N,F} <: AbstractArray{T,N}
  g::G
  f::F
  function LazyArray(::Type{T}, g::AbstractArray, f::AbstractArray...) where T
    G = typeof(g)
    F = typeof(f)
    new{G,T,ndims(first(f)),F}(g, f)
  end
end

function LazyArray(g::AbstractArray{S}, f::AbstractArray...) where S
  isconcretetype(S) ? gi = testitem(g) : @notimplemented
  fi = map(testitem,f)
  T = typeof(testitem(gi, fi...))
  LazyArray(T, g, f...)
end

IndexStyle(::Type{<:LazyArray}) = IndexCartesian()

#@fverdugo the signature of the index i... has to be improved
# so that it is resilient to the different types of indices

@inline array_cache(a::AbstractArray,i...) = nothing

function array_cache(a::LazyArray,i...)
  @notimplementedif ! all(map(isconcretetype, map(eltype, a.f)))
  if ! (eltype(a.g) <: Function)
    @notimplementedif ! isconcretetype(eltype(a.g))
  end
  gi = testitem(a.g)
  fi = Tuple(testitem.(a.f))
  cg = return_cache(a.g,i...)
  cf = map(fi -> return_cache(fi,i...),a.f)
  cgi = return_cache(gi, fi...)
  cg, cgi, cf
end

function array_cache(a::LazyArray)
@notimplementedif ! all(map(isconcretetype, map(eltype, a.f)))
if ! (eltype(a.g) <: Function)
  @notimplementedif ! isconcretetype(eltype(a.g))
end
gi = testitem(a.g)
fi = Tuple(testitem.(a.f))
cg = array_cache(a.g)
cf = map(array_cache,a.f)
cgi = return_cache(gi, fi...)
cg, cgi, cf
end

# @inline getindex!(c,a::AbstractArray,i...) = a[i...]

#@fverdugo the signature of the index i... has to be improved
# so that it is resilient to the different types of indices
# @santiagobadia : Can you handle this? I am not sure what you
# have in mind
@inline function getindex!(cache, a::LazyArray, i...)
  cg, cgi, cf = cache
  gi = getindex!(cg, a.g, i...)
  fi = map((ci,ai) -> getindex!(ci,ai,i...),cf,a.f)
  # fi = getitems!(cf, a.f, i...)
  vi = evaluate!(cgi, gi, fi...)
  # vi
end

function Base.getindex(a::LazyArray, i...)
  ca = array_cache(a)
  getindex!(ca, a, i...)
end

function Base.size(a::LazyArray)
  size(first(a.f))
end

# Particular implementations for Fill

function lazy_map(f::Fill, a::Fill...)
  ai = _getvalues(a...)
  r = evaluate(f.value, ai...)
  s = common_size(f, a...)
  Fill(r, s)
end

function lazy_map(::Type{T}, f::Fill, a::Fill...) where T
  lazy_map(f, a...)
end

function _getvalues(a::Fill, b::Fill...)
  ai = a.value
  bi = _getvalues(b...)
  (ai, bi...)
end

function _getvalues(a::Fill)
  ai = a.value
  (ai,)
end

# @santiagobadia : CompressedArray and Union{CompressedArray,Fill}
# To be done when starting Algebra part

# Operator

# function lazy_map(op::Operation,x::AbstractArray...)
  # lazy_map(Fill(op,length(first(x))),x...)
# end

function test_lazy_array(
  a::AbstractArray,
  x::AbstractArray,
  v::AbstractArray,
  cmp::Function=(==);
  grad=nothing)

  ax = lazy_map(a, x)
  test_array(ax, v, cmp)

  ca, cfi, cx = array_cache(a, x)
  t = true
  for i in 1:length(a)
    fi = getindex!(ca, a, i)
    xi = getindex!(cx, x, i)
    fxi = evaluate!(cfi, fi, xi)
    vi = v[i]
    ti = cmp(fxi, vi)
    t = t && ti
  end
  @test t

  if grad != nothing
    g = lazy_map(gradient, a)
    test_lazy_array(g, x, grad, cmp)
  end
end

function common_size(a::AbstractArray...)
  a1, = a
  c = all([size(a1) == size(ai) for ai in a])
  if !c
    error("Array sizes $(map(size,a)) are not compatible.")
  end
  l = size(a1)
  (l,)
end

# struct ArrayWithCounter{T,N,A,C} <: AbstractArray{T,N}
#   array::A
#   counter::C
#   function ArrayWithCounter(a::AbstractArray{T,N}) where {T,N}
#     c = zeros(Int,size(a))
#     c[:] .= 0
#     new{T,N,typeof(a),typeof(c)}(a,c)
#   end
# end

# Base.size(a::ArrayWithCounter) = size(a.array)

# function Base.getindex(a::ArrayWithCounter,i::Integer...)
#   a.counter[i...] += 1
#   a.array[i...]
# end

# Base.IndexStyle(::Type{<:ArrayWithCounter{T,N,A}}) where {T,A,N} = IndexStyle(A)

# function reset_counter!(a::ArrayWithCounter)
#   a.counter[:] .= 0
# end

# @santiagobadia : Do we want the same names for both ?????
# @inline array_cache(a::LazyArray,i...) = return_cache(a,i...)
# @inline get_index!(c,a::LazyArray,i...) = evaluate!(c,a,i...)
