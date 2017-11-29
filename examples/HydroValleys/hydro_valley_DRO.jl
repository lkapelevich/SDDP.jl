#  Copyright 2017, Oscar Dowson and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################

using SDDP, JuMP, Clp, Base.Test, SDDPPro

# For repeatability
srand(11111)

immutable TurbineF
    flowknots::Vector{Float64}
    powerknots::Vector{Float64}
end

immutable ReservoirH
    min::Float64
    max::Float64
    initial::Float64
    turbine::TurbineF
    spill_cost::Float64
    inflows::Vector{Float64}
end

valley_chain = [
    ReservoirH(0, 200, 200, TurbineF([50, 60, 70], [55, 65, 70]), 1000, [0, 20, 50]),
    ReservoirH(0, 200, 200, TurbineF([50, 60, 70], [55, 65, 70]), 1000, [0, 0, 20])
]
turbine(i) = valley_chain[i].turbine

prices = [1, 2, 3]

N = length(valley_chain)

function buildmodel(measure::SDDP.AbstractRiskMeasure)

    # Initialise SDDP Model
    m = SDDPModel(
                sense           = :Max,
                stages          = 3,
                objective_bound = 1e6,
                risk_measure    = measure,
                cut_oracle      = DefaultCutOracle(),
                solver          = ClpSolver()
                                        ) do sp, stage

        # ------------------------------------------------------------------
        #   SDDP State Variables
        # Level of upper reservoir
        @state(sp, valley_chain[r].min <= reservoir[r=1:N] <= valley_chain[r].max, reservoir0==valley_chain[r].initial)

        # ------------------------------------------------------------------
        #   Additional variables
        @variables(sp, begin
            outflow[r=1:N]      >= 0
            spill[r=1:N]        >= 0
            inflow[r=1:N]       >= 0
            generation_quantity >= 0 # Total quantity of water
            # Proportion of levels to dispatch on
            0 <= dispatch[r=1:N, level=1:length(turbine(r).flowknots)] <= 1
        end)

        # ------------------------------------------------------------------
        # Constraints
        @constraints(sp, begin
            # flow from upper reservoir
            reservoir[1] == reservoir0[1] + inflow[1] - outflow[1] - spill[1]
            # other flows
            flow[i=2:N], reservoir[i] == reservoir0[i] + inflow[i] - outflow[i] - spill[i] + outflow[i-1] + spill[i-1]

            # Total quantity generated
            generation_quantity == sum(turbine(r).powerknots[level] * dispatch[r,level] for r in 1:N for level in 1:length(turbine(r).powerknots))

            # ------------------------------------------------------------------
            # Flow out
            turbineflow[r=1:N], outflow[r] == sum(turbine(r).flowknots[level] * dispatch[r, level] for level in 1:length(turbine(r).flowknots))

            # Dispatch combination of levels
            dispatched[r=1:N], sum(dispatch[r, level] for level in 1:length(turbine(r).flowknots)) <= 1
        end)

        # rainfall noises
        for i in 1:N
            if stage > 1 # in future stages random inflows
                @rhsnoise(sp, rainfall = valley_chain[i].inflows, inflow[i] <= rainfall)
            else # in the first stage deterministic inflow
                @constraint(sp, inflow[i] <= valley_chain[i].inflows[1])
            end
        end

        # ------------------------------------------------------------------
        #   Objective Function
        @stageobjective(sp, prices[stage]*generation_quantity - sum(valley_chain[i].spill_cost * spill[i] for i in 1:N))

    end

end

# Build model with DRO
m = buildmodel(DRO(sqrt(2/3)-1e-6))
# (Note) radius ≈ sqrt(2/3), will set all noise probabilities to zero except the worst case noise
# (Why?):
# The distance from the uniform distribution (the assumed "true" distribution)
# to a corner of a unit simplex is sqrt(S-1)/sqrt(S) if we have S scenarios. The corner
# of a unit simplex is just a unit vector, i.e.: [0 ... 0 1 0 ... 0]. With this probability
# vector, only one noise has a non-zero probablity.

SDDP.solve(m,
    max_iterations = 10
)

# In the worst case noise (0 inflows) the profit is:
#  Reservoir1: 70 * $3 + 70 * $2 + 65 * $1 +
#  Reservoir2: 70 * $3 + 70 * $2 + 70 * $1
#  = $835
@test isapprox(getbound(m), 835.0, atol=1e-3)

# Something less conservative
m = buildmodel(DRO(1/6))

SDDP.solve(m,
    max_iterations = 20
)

@test isapprox(getbound(m), 836.695, atol=1e-3)
