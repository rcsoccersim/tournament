def system command
    # raise "Could not start '#{command} (return code was #{$?})'." unless Kernel::system command
    Kernel::system command
end

def sleep time
    # puts "Waiting #{time} seconds..."
    Kernel::sleep time
end

class Array
    def perm(n = size)
        if size < n or n < 0
        elsif n == 0
            yield([])
        else
            self[1..-1].perm(n - 1) do |x|
                (0...n).each do |i|
                    yield(x[0...i] + [first] + x[i..-1])
                end
            end
            self[1..-1].perm(n) do |x|
                yield(x)
            end
        end
    end
    
    def rotate
        clone.rotate!
    end
    
    def rotate!
        push shift
        self
    end
end

class Range
    def Range.parse range
        Range.new(*range.split("..").map { |i| i.to_i })
    end
end

class Time
    def readable
        "%4d%.2d%.2d%.2d%.2d" % [year, month, day, hour, min]
    end
end

class TeamQueue
    def initialize teams
        @teams = teams.clone
        @queue = []
    end
    
    def next
        refill if @queue.empty?
        @queue.shift
    end
    
    def refill
        @queue.concat @teams
    end
end

class RotateTeamQueue < TeamQueue
    def refill
        @queue.concat @teams.rotate!
    end
end
