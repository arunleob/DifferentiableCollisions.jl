import Pkg; Pkg.activate("/Users/kevintracy/.julia/dev/DCD/extras")

using LinearAlgebra
using Convex, ECOS
using JLD2
using StaticArrays
import DCD
import MeshCat as mc

P1 = DCD.Cylinder(.5,1.6)
P2 = DCD.Cylinder(.8,1.2)

P1.r = 1*(@SVector randn(3))
P1.q = normalize((@SVector randn(4)))
P2.r = 1*(@SVector randn(3))
P2.q = normalize((@SVector randn(4)))

# @inline function polygon_problem_matrices(A::SMatrix{nh,2,T1,nh3},b::SVector{nh,T2},R::Float64, r::SVector{3,T3},n_Q_b::SMatrix{3,3,T4,9}) where {nh,nh3,T1,T2,T3,T4}
#     Q̃ = n_Q_b[:,SA[1,2]]
#     G_ort = hcat((@SMatrix zeros(nh,3)), -b, A)
#     h_ort = @SVector zeros(nh)
#
#     G_soc_top = SA[0 0 0 -R 0 0]
#     G_soc_bot = hcat(SA[-1 0 0 0;0 -1 0 0;0 0 -1 0], Q̃)
#     G_soc = [G_soc_top;G_soc_bot]
#     h_soc = [0;-r]
#     G_ort, h_ort, G_soc, h_soc
# end
# @inline function problem_matrices(polytope::Polytope{n,n3,T},r::SVector{3,T1},q::SVector{4,T2}) where {n,n3,T,T1,T2}
#     n_Q_b = dcm_from_q(q)
#     polytope_problem_matrices(polytope.A,polytope.b,r,n_Q_b)
# end
# @inline function problem_matrices(polytope::PolytopeMRP{n,n3,T},r::SVector{3,T1},p::SVector{3,T2}) where {n,n3,T,T1,T2}
#     n_Q_b = dcm_from_mrp(p)
#     polytope_problem_matrices(polytope.A,polytope.b,r,n_Q_b)
# end

x = Variable(3)
γ1 = Variable()
γ2 = Variable()
α = Variable()

Q1 = DCD.dcm_from_q(P1.q)
bz1 = Q1*SA[1,0,0]
Q2 = DCD.dcm_from_q(P2.q)
bz2 = Q2*SA[1,0,0]

prob = minimize(α)
prob.constraints += α >= 0

prob.constraints += norm(x - (P1.r + γ1*bz1)) <= α*P1.R
prob.constraints += γ1 <=  α*P1.L/2
prob.constraints += γ1 >= -α*P1.L/2
prob.constraints += (x - (P1.r - α*bz1*P1.L/2))'*bz1 >= 0
prob.constraints += (x - (P1.r + α*bz1*P1.L/2))'*bz1 <= 0

prob.constraints += norm(x - (P2.r + γ2*bz2)) <= α*P2.R
prob.constraints += γ2 <=  α*P2.L/2
prob.constraints += γ2 >= -α*P2.L/2
prob.constraints += (x - (P2.r - α*bz2*P2.L/2))'*bz2 >= 0
prob.constraints += (x - (P2.r + α*bz2*P2.L/2))'*bz2 <= 0

solve!(prob, ECOS.Optimizer)
α = α.value
x = vec(x.value)

α2,x2 = DCD.proximity(P1,P2; pdip_tol = 1e-10, verbose = true)
# # new formulation
# G_ort1, h_ort1, G_soc1, h_soc1 = polygon_problem_matrices(P1.A,P1.b,P1.R, P1.r,DCD.dcm_from_q(P1.q))
# G_ort2, h_ort2, G_soc2, h_soc2 = polygon_problem_matrices(P2.A,P2.b,P2.R, P2.r,DCD.dcm_from_q(P2.q))
# c,G,h,idx_ort,idx_soc1,idx_soc2 = DCD.combine_problem_matrices(G_ort1, h_ort1, G_soc1, h_soc1,G_ort2, h_ort2, G_soc2, h_soc2)
# x_opt, s_opt, z_opt = DCD.solve_socp(c,G,h,idx_ort,idx_soc1,idx_soc2; verbose = true, pdip_tol = 1e-9)
# x = Variable(3)
# y1 = Variable(2)
# y2 = Variable(2)
# s1 = Variable(3)
# s2 = Variable(3)
# α = Variable()
#
# prob = minimize(α)
# prob.constraints += α >= 0
#
# prob.constraints += G_ort1*[x;α;y1] <= h_ort1
# s1 = h_soc1 - G_soc1*[x;α;y1]
# prob.constraints += norm(s1[2:end]) <= s1[1]
#
# prob.constraints += G_ort2*[x;α;y2] <= h_ort2
# s2 = h_soc2 - G_soc2*[x;α;y2]
# prob.constraints += norm(s2[2:end]) <= s2[1]
#
# solve!(prob, ECOS.Optimizer)
# α = α.value
# x = vec(x.value)

# α2, x2 = DCD.proximity(P1,P2)

# vis = mc.Visualizer()
# open(vis)

c1 = [245, 155, 66]/255
c2 = [2,190,207]/255


if α > 1
    trans_1 = 1.0
    trans_2 = 0.5
else
    trans_2 = 1.0
    trans_1 = 0.5
end

DCD.build_primitive!(vis, P1, :polytope1; α = 1.0,color = mc.RGBA(c1..., trans_1))
DCD.build_primitive!(vis, P2, :polytope2; α = 1.0,color = mc.RGBA(c2..., trans_1))
DCD.build_primitive!(vis, P1, :polytope1_big; α = α,color = mc.RGBA(c1..., trans_2))
DCD.build_primitive!(vis, P2, :polytope2_big; α = α,color = mc.RGBA(c2..., trans_2))

DCD.update_pose!(vis[:polytope1], P1)
DCD.update_pose!(vis[:polytope2], P2)
DCD.update_pose!(vis[:polytope1_big], P1)
DCD.update_pose!(vis[:polytope2_big], P2)

sph_p1 = mc.HyperSphere(mc.Point(x...), 0.1)
mc.setobject!(vis[:p1], sph_p1, mc.MeshPhongMaterial(color = mc.RGBA(1.0,0,0,1.0)))

@info α


using Test
@test norm(x-x2) <= 1e-4
@test abs(α - α2) <= 1e-4

# @test norm(x-x_opt[1:3]) <= 1e-4
# @test abs(α - x_opt[4]) <= 1e-4
