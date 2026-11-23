# Bộ sinh dữ liệu tổng hợp theo mục 4.3 của Agrawal & Srikant (1994).
# Tham số: D giao dịch, T độ dài TB (Poisson), I kích thước TB của mẫu (Poisson),
# L số mẫu tiềm năng, N số item. Trọng số mẫu ~ mũ(1); corruption ~ N(0.5, 0.1);
# một phần mẫu sau lấy từ mẫu trước (correlation, mũ trung bình 0.5).
using Random

function poisson(rng, λ)
    limit = exp(-λ); k = 0; p = 1.0
    while true
        k += 1
        p *= rand(rng)
        p <= limit && return k - 1
    end
end

function gen_quest(path::AbstractString; D::Int, T::Real, I::Real = 4, L::Int = 2000, N::Int = 1000,
                   seed::Int = 14, corr::Float64 = 0.5, c_mean::Float64 = 0.5, c_var::Float64 = 0.1)
    rng = MersenneTwister(seed)
    patterns = Vector{Vector{Int}}(undef, L)
    for l in 1:L
        sz = clamp(max(1, poisson(rng, I)), 1, N)
        items = Int[]
        if l > 1
            prev = patterns[l - 1]
            frac = min(1.0, -corr * log(1 - rand(rng)))
            m = min(length(prev), round(Int, frac * sz))
            append!(items, prev[randperm(rng, length(prev))[1:m]])
        end
        while length(items) < sz
            it = rand(rng, 1:N)
            it in items || push!(items, it)
        end
        patterns[l] = items
    end
    w = -log.(1 .- rand(rng, L))
    cum = cumsum(w ./ sum(w))
    corruption = [clamp(c_mean + sqrt(c_var) * randn(rng), 0.0, 1.0) for _ in 1:L]
    pick() = min(L, searchsortedfirst(cum, rand(rng)))

    carry = 0   # mẫu không vừa giao dịch trước được chuyển sang giao dịch sau
    open(path, "w") do io
        for _ in 1:D
            tlen = max(1, poisson(rng, T))
            t = Set{Int}()
            while length(t) < tlen
                pid = carry != 0 ? carry : pick()
                carry = 0
                pat = copy(patterns[pid])
                while !isempty(pat) && rand(rng) < corruption[pid]
                    deleteat!(pat, rand(rng, 1:length(pat)))
                end
                if !isempty(t) && length(t) + length(pat) > tlen
                    if rand(rng) < 0.5
                        union!(t, pat)
                    else
                        carry = pid
                        break
                    end
                else
                    union!(t, pat)
                end
            end
            println(io, join(sort!(collect(t)), " "))
        end
    end
    return path
end
