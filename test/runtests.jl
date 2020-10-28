using Aqua,
      DataFrames,
      ModelParameters,
      Test,
      Unitful

@testset "param math" begin
    # We don't have to test everything, that is for AbstractNumbers.jl
    @test 2 * Param(5.0; bounds=(5.0, 15.0)) == 10.0
    @test Param(5.0; bounds=(5.0, 15.0)) + 3 == 8.0
    @test Param(5.0; bounds=(5.0, 15.0))^2 === 25.0
    @test Param(5; bounds=(5.0, 15.0))^2 === 25
end

struct S1{A,B,C,D,E,F}
    a::A
    b::B
    c::C
    d::D
    e::E
    f::F
end

struct S2{H,I,J}
    h::H
    i::I
    j::J
end

s2 = S2(
    Param(99),
    7,
    Param(100.0; bounds=(50.0, 150.0))
)

s1 = S1(
   Param(1.0; bounds=(5.0, 15.0)),
   Param(2.0; bounds=(5.0, 15.0)),
   Param(3.0; bounds=(5.0, 15.0)),
   Param(4.0),
   (Param(5.0; bounds=(5.0, 15.0)), Param(6.0; bounds=(5.0, 15.0))),
   s2,
)

pars = ModelParameters.params(s1)

@testset "params are correctly flattened from an object" begin
    @test length(pars) == 8
    @test all(map(p -> isa(p, Param), pars))
end

@testset "param math" begin
    # We don't have to test everything, that is for AbstractNumbers.jl
    @test 2 * Param(5.0; bounds=(5.0, 15.0)) == 10.0
    @test Param(5.0; bounds=(5.0, 15.0)) + 3 == 8.0
    @test Param(5.0; bounds=(5.0, 15.0))^2 === 25.0
    @test Param(5; bounds=(5.0, 15.0))^2 === 25
end

@testset "missing fields are added to Model Params" begin
    m = Model(s1);
    @test all(map(p -> propertynames(p) == (:val, :bounds), params(m)))
end

@testset "getproperties returns column tuples of param fields" begin
    m = Model(s1);
    @test m.component === (S1, S1, S1, S1, S1, S1, S2, S2)
    @test m.field === (:a, :b, :c, :d, :e, :e, :h, :j)
    @test m.val === (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 99, 100.0)
    @test m.bounds == ((5.0, 15.0), (5.0, 15.0), (5.0, 15.0), nothing,
                       (5.0, 15.0), (5.0, 15.0), nothing, (50.0, 150.0))
end

@testset "setproperties updates and adds param fields" begin
    m = Model(s1)
    m.val = m.val .* 2
    @test m.val == (2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 198, 200.0)
    m.newfield = ntuple(x -> x, 8)
    @test m.newfield == ntuple(x -> x, 8)
end

@testset "simpify model" begin
    m = Model(s1);
    simple = simplify(m)
    @test params(simple) == ()
    @test simple.c == 3.0
    @test simple.f.j == 100.0
end

@testset "Tables interface" begin
    m = Model(s1);
    s = Tables.schema(m)
    @test keys(m) == s.names == (:component, :field, :val, :bounds)
    @test s.types == (
        UnionAll,
        Symbol,
        Union{Float64,Int64},
        Union{Nothing,Tuple{Float64,Float64}},
    )
    df = DataFrame(m)
    @test all(df.component .== m.component)
    @test all(df.field .== m.field)
    @test all(df.val .== m.val)
    @test all(df.bounds .== m.bounds)

    df.val .*= 3
    ModelParameters.update!(m, df)
    @test m.val == (3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 297, 300.0)
end

@testset "use Unitful units, with StaticModel" begin
    s1 = S1(
       Param(1.0; bounds=(5.0, 15.0)),
       Param(2.0; bounds=(5.0, 15.0), units=u"s"),
       Param(3.0; bounds=(5.0, 15.0), units=u"K"),
       Param(4.0; units=u"m"),
       Param(5.0; bounds=(5.0, 15.0)),
       Param(6.0),
    )
    s2 = S2( s1,
        Param(7.0; bounds=(50.0, 150.0), units=u"m*s^2"),
        Param(8.0),
    )
    m = StaticModel(s2)
    @test m.units == (nothing, u"s", u"K", u"m", nothing, nothing, u"m*s^2", nothing)
    # Values have units now
    @test ModelParameters.paramval(m) == (1.0, 2.0u"s", 3.0u"K", 4.0u"m", 5.0, 6.0, 7.0u"m*s^2", 8.0)
end


# @testset "interactive model" begin
#     color(i) = colors[i%length(colors)+1]
#     colors = ["black", "gray", "silver", "maroon", "red", "olive", "yellow", "green", "lime", "teal", "aqua", "navy", "blue", "purple", "fuchsia"]
#     width, height = 700, 300
#     nsamples = 256
#     model = (;
#         sample_step=Param(val=0.05, range=0.01:0.001:0.1, label="Sample step"),
#         phase=Param(val=0.0, range=0:0.1:2pi, label="Phase"),
#         radii=Param(val=20,range=0:0.1:60, label="Radus")
#     )
#     interface = InteractModel(model; grouped=false) do m
#         cxs_unscaled = [i * m.sample_step + m.phase for i in 1:nsamples]
#         cys = sin.(cxs_unscaled) .* height/3 .+ height/2
#         cxs = cxs_unscaled .* width/4pi
#         dom"svg:svg[width=$width, height=$height]"(
#         (dom"svg:circle[cx=$(cxs[i]), cy=$(cys[i]), r=$(m.radii), fill=$(color(i))]"()
#                 for i in 1:nsamples)...
#         )
#     end
#     display(interface)

#     @testset "Test the tables interface and getproperty work on InteractModel too" begin
#         df = DataFrame(interface)
#         @test Tuple(df.val) == interface.val == (0.05, 0.0, 20)
#         @test Tuple(df.range) == interface.range == (0.01:0.001:0.1, 0.0:0.1:6.2, 0.0:0.1:60.0)
#         @test Tuple(df.label) == interface.label == ("Sample step", "Phase", "Radus")
#     end
# end
