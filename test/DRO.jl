#  Copyright 2017, Lea Kapelevich

@testset "PopStd" begin
    x = rand(10)
    @test isapprox(SDDP.popstd(x), std(x, corrected=false), atol=1e-9)
end
@testset "UpdateProbabilities" begin
    S = 5
    r = 0.25
    theta = -float([2; 1; 3; 4; 5])
    newprobabilities = zeros(S)
    SDDP.updateprobabilities!(newprobabilities, DRO(r), :Min, theta, S)
    @test isapprox(newprobabilities, [0.279057,0.358114,0.2,0.120943,0.0418861], atol=1e-6)
    SDDP.updateprobabilities!(newprobabilities, DRO(r), :Max, -theta, S)
    @test isapprox(newprobabilities, [0.279057,0.358114,0.2,0.120943,0.0418861], atol=1e-6)
    r = 0.4
    SDDP.updateprobabilities!(newprobabilities, DRO(r), :Min, theta, S)
    @test isapprox(newprobabilities, [0.324162,0.472486,0.175838,0.027514,0.0], atol=1e-6)
    SDDP.updateprobabilities!(newprobabilities, DRO(r), :Max, -theta, S)
    @test isapprox(newprobabilities, [0.324162,0.472486,0.175838,0.027514,0.0], atol=1e-6)
    r = sqrt(0.8)
    SDDP.updateprobabilities!(newprobabilities, DRO(r), :Min, theta, S)
    @test isapprox(newprobabilities, [0,1,0,0,0.0], atol=1e-6)
end
