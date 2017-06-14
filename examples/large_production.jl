#==
                            The Multiple Widget Producer

Let us consider a producer of a large variety of widgets. They sell these
widgets on demand from a catalogue and promise their customers that all widgets
are available for purchase at any time. Therefore, they must maintain a stock
of each widget in a warehouse for dispatch. Future demand for widgets is
unknown, but follows an auto-regressive process (if there is strong demand for a
widget in one time period, there will likely be strong demand in the next).

However, the number of different types of widgets exceeds the capacity of the
factory to produce them simultaneously. Therefore, the factory produces
quantities of particular widgets in batches. The goal of the factory is to
schedule the production of widgets such that they minimise the number of
unfufilled orders, whilst minimising the holding cost of widgets.

==#

using SDDP, JuMP, Clp

N = 10 # 10 types of widgets

#==
    Demand follows a mean reverting, auto-regressive process with lag 1
        y = (1 - λ) * ALPHA * yₜ + λ * (yₜ - μ) + ɛ ~ OMEGA
==#
# mean reversion rate
λ = 0.5
# process mean
μ = ones(N)
# cross-cofficients (I = indepdendent processes)
ALPHA = eye(N,N)
# stagewise-independent noises
OMEGA = rand(N, 5) # 5 noises

# initial demand for widgets
INITIAL_DEMAND  = rand(N)
# initial stock of widgets
INITIAL_WIDGETS = rand(N)
# max warehouse
MAX_WIDGETS = ones(N)
# cost of holding widgets
HOLDING_COST = 0.1 * ones(N)
# cost of missing demand
UNFUFILLED_COST = ones(N)

m = SDDPModel(
    sense  = :Min,
    stages = 12,
    objective_bound = -1e6,
    solver = ClpSolver()
                        ) do sp, t
    @states(sp, begin
        # number of widgets in storage
        0 <= widgets[i=1:N] <= MAX_WIDGETS[i], initial_widgets==INITIAL_WIDGETS[i]
        # auto-regressive state for demand
        demand[i=1:N] >= 0,  initial_demand==INITIAL_DEMAND[i]
    end)

    @variables(sp, begin
        # widgets to produce
        production[i=1:N] >= 0
        # unmet demand
        unmet_demand[i=1:N] >= 0
        # order fufillment
        order_fufillment[i=1:N] >= 0
    end)

    @constraints(sp, begin
        # meet demand
        demand  .== order_fufillment + unmet_demand
        # supply from widgets at start of period
        order_fufillment .<= initial_widgets
        # new state of widgets
        widgets .== initial_widgets + production - order_fufillment
    end)

    for i in 1:size(OMEGA, 1)
        @noise(sp, j=1:size(OMEGA, 2),
            demand[i] == (1-λ) * ALPHA[i, :] * initial_demand + λ * (initial_demand[i] - μ[i]) + OMEGA[i, j]
        )
    end

    stageobjective!(sp, dot(HOLDING_COST, widgets) + dot(UNFUFILLED_COST, unmet_demand))

end
