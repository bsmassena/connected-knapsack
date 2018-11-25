using GLPKMathProgInterface
using JuMP

M = typemax(Int16)

v = 5
v_range = 1:v
weights = [50, 20, 30, 65, 15]
values = [20, 40, 35, 65, 10]
limit = 100

#    1  2  3  4  5
e = [
    [0, 1, 1, 1, 0]
    [1, 0, 1, 0, 0]
    [1, 1, 0, 1, 1]
    [1, 0, 1, 0, 0]
    [0, 0, 1, 0, 0]
]
e = reshape(e, 5, 5)

m = Model(solver = GLPKSolverMIP());

@variable(m, f[v_range, v_range] >= 0, Int) # flow between vertices
@variable(m, receivers >= 0, Int) # n of receiver vertices
@variable(m, s[v_range], Bin) # sender vertex
@variable(m, c[v_range], Bin) # choosen vertices

@objective(m, Max, sum(c[i] * values[i] for i = v_range));

@constraints(m, begin
    receivers == sum((c[i]) for i = v_range) - 1 # (quantidade de vértices escolhidos - 1) 

    # flux constraints
    [i in v_range, j in v_range], f[i,j] <= e[i,j] * M # sem fluxo se não há aresta entre i e j
    [i in v_range, j in v_range], f[i,j] <= c[i] * M # sem fluxo se i não pertence a solução
    [i in v_range, j in v_range], f[i,j] <= c[j] * M # sem fluxo se j não pertence a solução
    
    # receivers constraints (gambiarras usando M pra garantir que um receiver envie 1 mensagem a menos do que recebe)
    [i in v_range], sum(f[i,j] for j = v_range) + 1 <= sum(f[j,i] for j = v_range) + M * (s[i] + (1 - c[i]))
    [i in v_range], sum(f[i,j] for j = v_range) + 1 >= sum(f[j,i] for j = v_range) - M * (s[i] + (1 - c[i]))

    # sender constraints
    [i in v_range], sum(f[i,j] for j = v_range) >= receivers - (M * (1 - s[i])) # caso i seja sender, deve enviar 'receivers' fluxos
    [j in v_range], sum(f[i,j] for i = v_range) <= M * (1 - s[j]) # caso j seja um sender, não deve receber fluxo
    sum(s[i] for i = v_range) == 1 # garante que haja apenas 1 sender
    [i in v_range], s[i] <= c[i] # sender deve pertencer a solução

    # knapsack constraints
    sum(c[i] * weights[i] for i = v_range) <= limit
end);

status = solve(m)

otm = getobjectivevalue(m)
sol = getvalue(f)
choosen = getvalue(c)
sender = getvalue(s)
rec = getvalue(receivers)

println("O valor otimo e $(otm).")
println("Fluxos:")
for i = v_range
    println(sol[i,:])
end
println("\nSolução: $(choosen[:])")
println("Sender: $(sender[:])")
println("Receivers: $(rec)")