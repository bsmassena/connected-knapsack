require 'set'
require_relative 'graph.rb'
require_relative 'moc.rb'
require_relative 'solver.rb'

def solve_all
    [8,10].each do |instance|
        (2..2).each do |run|
            instance_path = "instances/moc%02d" % instance
            output_path = "out/moc%02d/%d" % [instance, run]

            s = Solver.new(instance_path, output_path, run)
            s.solve
        end
    end
end
