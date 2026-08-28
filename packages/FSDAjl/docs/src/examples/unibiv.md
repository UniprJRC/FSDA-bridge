# unibiv

Scores every unit by how often it falls outside the limits for a single
variable and for each pair of variables. The lowest scoring units make a
natural clean starting subset for the forward search.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `Y` | `Matrix{Float64}` | `n x v` data matrix |

Optional, passed as name-value keywords:

| Argument | Description |
|---|---|
| `plots` | set to 1 to draw the confidence ellipses |
| `textlab` | set to 1 to label the flagged units on the plot |

## Example

```julia
using FSDA
using Printf

Y = eval_expr("table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")

fre = unibiv(Y)

ord = sortperm(fre[:, 4], rev = true)

for i in ord[1:5]
    @printf("  unit %5d   overall score %8.4f\n", Int(fre[i, 1]), fre[i, 4])
end

stop_engine()
```

## Output

An `n x 4` matrix, one row per unit: the unit number, how often it fell
outside a single-variable limit, how often it fell outside a two-variable
ellipse, and a pseudo Mahalanobis distance giving its overall score.

unibiv does not separate the forgeries in this dataset. Of the ten most
unusual notes, five are genuine and five are forged. It looks at one or two
variables at a time, so it finds notes with an extreme single measurement
rather than notes that are odd in the way a forgery is.

```
  unit   167   overall score  37.9145
  unit    40   overall score  35.5924
  unit   171   overall score  34.0312
  unit   161   overall score  33.8727
  unit     5   overall score  31.6626
```

## See also

- unibiv documentation: <https://rosa.unipr.it/FSDA/unibiv.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_mv.html>
