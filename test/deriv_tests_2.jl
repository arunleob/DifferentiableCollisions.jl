function kkt_R(capsule::DCD.Capsule{T},
           cone::DCD.Cone{T},
           x::SVector{nx,T1},
           s::SVector{nz,T7},
           z::SVector{nz,T2},
           r1::SVector{3,T3},
           q1::SVector{4,T4},
           r2::SVector{3,T5},
           q2::SVector{4,T6},
           idx_ort::SVector{n_ort,Ti},
           idx_soc1::SVector{n_soc1,Ti},
           idx_soc2::SVector{n_soc2,Ti}) where {T,nx,nz,n_ort,n_soc1,n_soc2,Ti,T1,T2,T3,T4,T5,T6,T7}

    G_ort1, h_ort1, G_soc1, h_soc1 = DCD.problem_matrices(capsule,r1,q1)
    G_ort2, h_ort2, G_soc2, h_soc2 = DCD.problem_matrices(cone,r2,q2)

    n_ort1 = length(h_ort1)
    n_ort2 = length(h_ort2)

    G_ort_top = G_ort1
    G_ort_bot = hcat(G_ort2, (@SVector zeros(n_ort2))) # add a column for γ (capsule)

    G_soc_top = G_soc1
    G_soc_bot = hcat(G_soc2, (@SVector zeros(n_soc2))) # add a column for γ (capsule)

    G_ = [G_ort_top;G_ort_bot;G_soc_top;G_soc_bot]
    h_ = [h_ort1;h_ort2;h_soc1;h_soc2]


    c = SA[0,0,0,1.0,0]

    [
    c + G_'*z;
    DCD.cone_product(h_ - G_*x, z, idx_ort, idx_soc1, idx_soc2)
    ]
end

function solve_alpha(capsule::DCD.Capsule{T},
           cone::DCD.Cone{T},
           r1,
           q1,
           r2,
           q2,
           idx_ort::SVector{n_ort,Ti},
           idx_soc1::SVector{n_soc1,Ti},
           idx_soc2::SVector{n_soc2,Ti}) where {T,n_ort,n_soc1,n_soc2,Ti}

    G_ort1, h_ort1, G_soc1, h_soc1 = DCD.problem_matrices(capsule,r1,q1)
    G_ort2, h_ort2, G_soc2, h_soc2 = DCD.problem_matrices(cone,r2,q2)

    n_ort1 = length(h_ort1)
    n_ort2 = length(h_ort2)

    G_ort_top = G_ort1
    G_ort_bot = hcat(G_ort2, (@SVector zeros(n_ort2))) # add a column for γ (capsule)

    G_soc_top = G_soc1
    G_soc_bot = hcat(G_soc2, (@SVector zeros(n_soc2))) # add a column for γ (capsule)

    G_ = [G_ort_top;G_ort_bot;G_soc_top;G_soc_bot]
    h_ = [h_ort1;h_ort2;h_soc1;h_soc2]


    x,s,z = DCD.solve_socp(SA[0,0,0,1.0,0],G_,h_,idx_ort,idx_soc1,idx_soc2; verbose = false, pdip_tol = 1e-6)
    [x[4]]
end

let

    cone = DCD.Cone(2.0,deg2rad(22))
    cone.r = 0.3*(@SVector randn(3))
    cone.q = normalize((@SVector randn(4)))

    capsule = DCD.Capsule(.3,1.2)
    capsule.r = (@SVector randn(3))
    capsule.q = normalize((@SVector randn(4)))

    G_ort1, h_ort1, G_soc1, h_soc1 = DCD.problem_matrices(capsule)
    G_ort2, h_ort2, G_soc2, h_soc2 = DCD.problem_matrices(cone)

    n_ort1_ = length(h_ort1)
    n_ort2_ = length(h_ort2)
    n_soc1_ = length(h_soc1)
    n_soc2_ = length(h_soc2)
    n_ort_ = n_ort1_ + n_ort2_

    G_ort_top = G_ort1
    G_ort_bot = hcat(G_ort2, (@SVector zeros(n_ort2_))) # add a column for γ (capsule)

    G_soc_top = G_soc1
    G_soc_bot = hcat(G_soc2, (@SVector zeros(n_soc2_))) # add a column for γ (capsule)

    G = [G_ort_top;G_ort_bot;G_soc_top;G_soc_bot]
    h = [h_ort1;h_ort2;h_soc1;h_soc2]

    idx_ort = SVector{n_ort_}(1:n_ort_)
    idx_soc1 = SVector{n_soc1_}((n_ort_ + 1):(n_ort_ + n_soc1_))
    idx_soc2 = SVector{n_soc2_}((n_ort_ + n_soc1_ + 1):(n_ort_ + n_soc1_ + n_soc2_))

    # solve socp
    x,s,z = DCD.solve_socp(SA[0,0,0,1.0,0],G,h,idx_ort,idx_soc1,idx_soc2; verbose = true, pdip_tol = 1e-6)

    # indices
    nx = length(x); nz = length(z)
    idx_x = SVector{nx}(1:length(x))
    idx_z = SVector{nz}((length(x) + 1):(length(x) + length(z)))
    idx_r1 = SVector{3}(1:3)
    idx_q1 = SVector{4}(4:7)
    idx_r2 = SVector{3}(8:10)
    idx_q2 = SVector{4}(11:14)

    # find the actual gradient
    dα_dθ=FiniteDiff.finite_difference_jacobian(_θ -> solve_alpha(capsule,cone,_θ[idx_r1],_θ[idx_q1],_θ[idx_r2],_θ[idx_q2],idx_ort,idx_soc1,idx_soc2), [capsule.r;capsule.q;cone.r;cone.q])

    # analytical
    dR_dθ=ForwardDiff.jacobian(_θ -> kkt_R(capsule,cone,x,s,z,_θ[idx_r1],_θ[idx_q1],_θ[idx_r2],_θ[idx_q2],idx_ort,idx_soc1,idx_soc2), [capsule.r;capsule.q;cone.r;cone.q])

    # build full matrix
    Z = Matrix(blockdiag(sparse(Diagonal(z[idx_ort])),sparse(DCD.arrow(z[idx_soc1])),sparse(DCD.arrow(z[idx_soc2]))))
    s̃ = s
    # s̃ = h - G*x
    S = Matrix(blockdiag(sparse(Diagonal(s̃[idx_ort])),sparse(DCD.arrow(s̃[idx_soc1])),sparse(DCD.arrow(s̃[idx_soc2]))))
    dR_dw = [zeros(length(x),length(x)) G'; -Z*G S]

    dw_dθ = -dR_dw\dR_dθ

    @show norm(vec(dα_dθ) - vec(dw_dθ[4,:]))
    @test norm(vec(dα_dθ) - vec(dw_dθ[4,:])) < 1e-3

    # now do it the fast way
    r1 = -dR_dθ[idx_x,:]
    r2 = -dR_dθ[idx_z,:]
    # r,c = size(Z)
    # Z = SMatrix{r,c}(Z)
    Z = DCD.scaling_2(z[idx_ort],DCD.arrow(z[idx_soc1]),DCD.arrow(z[idx_soc2]))
    S = DCD.NT_scaling_2(s[idx_ort],DCD.arrow(s[idx_soc1]), cholesky(DCD.arrow(s[idx_soc1])), DCD.arrow(s[idx_soc2]), cholesky(DCD.arrow(s[idx_soc2])))
    Δx = (G'*((S\Z)*G))\(r1 - G'*(S\r2))
    Δz = S\(r2 + Z*G*Δx)
    @test norm(dw_dθ - [Δx;Δz]) < 1e-6




    # cone_prod_res= DCD.cone_product(s,z,idx_ort,idx_soc1,idx_soc2)
    # @show norm(cone_prod_res)
    # W = DCD.calc_NT_scalings(s,z,idx_ort,idx_soc1,idx_soc2)
    # λ1 = W\s
    # λ2 = W*z
    # @show norm(λ1 - λ2)
    # # λ = W*z
    # λ = W\s
    # @show norm(DCD.cone_product(λ,λ,idx_ort,idx_soc1,idx_soc2))
    # @show norm(DCD.cone_product(λ1,λ1,idx_ort,idx_soc1,idx_soc2))
    #
    # dx = @SVector randn(length(x))
    # dz = @SVector randn(length(s))
    # ds = @SVector randn(length(s))
    #
    #
    # # bx = -rx
    # λ_ds = DCD.inverse_cone_product(λ,ds,idx_ort,idx_soc1,idx_soc2)
    # dz̃ = W\(dz - W*(λ_ds))
    # G̃ = W\G
    # F = cholesky(Symmetric(G̃'*G̃))
    # Δx = F\(dx + G̃'*dz̃)
    # Δz = W\(G̃*Δx - dz̃)
    # Δs = W*(λ_ds - W*Δz)
    #
    # @info "first solve"
    # @show norm(Δx)
    # @show norm(Δz)
    # @show norm(Δs)
    #
    # @show norm(G'*Δz - dx)
    # @show norm(Δs + G*Δx - dz)
    # @show norm(DCD.cone_product(λ, W*Δz + W\Δs,idx_ort, idx_soc1, idx_soc2) - ds)

    # @show "iterative refinement"
    # dx2 = -(G'*Δz)
    # dz2 = -(Δs + G*Δx)
    # ds2 = -(DCD.cone_product(λ, W*Δz + W\Δs,idx_ort, idx_soc1, idx_soc2))
    #
    # λ_ds2 = DCD.inverse_cone_product(λ,ds2,idx_ort,idx_soc1,idx_soc2)
    # dz̃2 = W\(dz2 - W*(λ_ds2))
    # G̃ = W\G
    # F = cholesky(Symmetric(G̃'*G̃))
    # Δx2 = F\(dx2 + G̃'*dz̃2)
    # Δz2 = W\(G̃*Δx2 - dz̃2)
    # Δs2 = W*(λ_ds2 - W*Δz2)
    #
    # Δx = Δx + Δx2
    # Δz = Δz + Δz2
    # Δs = Δs + Δs2
    #
    # @show norm(Δx)
    # @show norm(Δz)
    # @show norm(Δs)
    #
    # @show norm(G'*Δz - dx)
    # @show norm(Δs + G*Δx - dz)
    # @show norm(DCD.cone_product(λ, W*Δz + W\Δs,idx_ort, idx_soc1, idx_soc2) - ds)
end
