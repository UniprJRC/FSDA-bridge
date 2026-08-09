# mahalFS - Mahalanobis distances, in squared units, for each row of Y.
#
#   d = mahalFS(Y, μ, Σ)
#
#   Y  n x v data matrix (n observations, v variables)
#   μ  1 x v centroid            (MU in the FSDA documentation)
#   Σ  v x v covariance matrix   (SIGMA in the FSDA documentation)
#   d  n x 1 squared distances, in the row order of Y
#
# Full documentation: the mahalFS page in the FSDAjl docs.

using FSDA
using Statistics


# Example 1 - Example of computation of MD.

Y = [ 0.52 -1.10;  1.83  0.14; -0.09  1.53;  0.32 -0.77;  1.10  0.37;
     -0.86  0.26;  0.15 -1.44;  0.79  0.33; -1.21  0.71;  0.46 -0.05]

# Compute MD using as centroid the medians and shape matrix Σ
μ = median(Y, dims = 1)
Σ = [0.3 0.4; 0.4 1.0]

d = mahalFS(Y, μ, Σ)

println(round.(vec(d)[1:3], digits = 4))

stop_engine()
