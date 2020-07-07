require 'util'
require 'config'
require 'results'
require 'match'

require 'fileutils'

DEFAULTS_FILE = "config/defaults.yml"
SHOW_EXCEPTION_BACKTRACE = false

class Tournament
    def initialize config
        @config = config
        @match_index = 0
        
        parse_config
        run
    end
    
    def parse_config
        raise "No tournament configuration file specified (use --config=<file>)." if @config.config.nil?
         
        @mode = "mode_#{@config.mode}"
        @teams = @config.teams
        @matches = @config.matches

        raise "Invalid number of hosts (at least one per team is required)." if @config.hosts.size < 2
        raise "Invalid number of hosts (must be even)." if @config.hosts.size % 2 != 0
        
        configure_logging
    end
    
    def configure_logging
        @log_dir = Time.now.strftime @config.log_dir
        @results_csv = File.join @log_dir, "results.log"
        @results_xml = File.join @log_dir, "results.xml"
        
        raise "Log directory #{@log_dir} already exists (use --resume to resume aborted tournament)." if FileTest.exists? @log_dir
        puts "Using directory #{@log_dir}."
    end
    
    def run
        raise "Unknown mode specified." unless respond_to? @mode
        
        check_teams
        cleanup
        setup
        build if @config.build
        send @mode
        teardown
        
        puts "Finished tournament."
    end
    
    def mode_group
        puts "Starting group tournament with #{@teams.size} teams."
        
        matchlist = []
        
        left = TeamQueue.new @teams
        right = RotateTeamQueue.new @teams
        
        while matchlist.size < (@teams.size * (@teams.size - 1) / 2) do
            matchlist << [left.next, right.next]
        end
        
        matchlist.each do |match|
            start_match match[0], match[1]
        end
    end
    
    def mode_group_perm
        puts "Starting group tournament with #{@teams.size} teams."
        
        @teams.perm(2) do |match|
            start_match match[0], match[1]
        end
    end
    
    def mode_one_vs_all
        team, *opponents = @teams
        
        puts "Starting tournament #{team} against #{opponents.size} teams."
        
        opponents.each do |opponent|
            start_match team, opponent
        end
    end

    def mode_matchlist
        raise "No matches listed." if @matches.empty?
        
        puts "Starting #{@matches.size} matches from list."
        
        @matches.each do |match|
            start_match match[0], match[1]
        end
    end
    
    def mode_single_match
        puts "Starting single match."
        
        raise "Wrong team count." unless @teams.size == 2
        
        start_match @teams[0], @teams[1]
    end
    
    def start_match team1, team2
        return if @config.max_matches >= 0 and @match_index + 1 > @config.max_matches
        
        puts "Starting match #{team1} vs #{team2}. [Press ctrl+c to abort match.]"
        
        Match.new(team1, team2, @results_csv, @log_dir, @config).start
        @match_index = @match_index + 1
        
        results
        
        puts "Waiting for next match to start... [Press ctrl+c to abort tournament.]"

        sleep @config.match_sleep
    end
    
    def check_teams
        @teams = [] if @teams.nil?
        @matches = [] if @matches.nil?
        @teams = @teams.map { |team| File.join @config.teams_dir, team }

        if @mode == "mode_matchlist"
            @matches = @matches.each { |match| match[0] = File.join(@config.teams_dir, match[0]); match[1] = File.join(@config.teams_dir, match[1]) }
            @matches.each { |match| @teams << match[0]; @teams << match[1] }
            @teams.uniq!
        end

        @teams.each { |team| check_team team }
    end

    def check_team team
        check_file File.join(team, "team.yml"), false
        check_file File.join(team, "start"), true
        check_file File.join(team, "kill"), true
    end

    def check_file filename, executable
        unless FileTest.exists? filename 
            raise "Missing team file '#{filename}'."
        end

        if executable and not FileTest.executable? filename
            raise "Team file '#{filename}' not executable."
        end

        unless FileTest.readable? filename
            raise "Team file '#{filename}' not readable."
        end
    end
    
    def cleanup
        puts "Cleanup..."
        
        FileUtils.remove Dir.glob("team_?_start.sh")
        FileUtils.remove Dir.glob("*#{@config.game_log_extension}")
        FileUtils.remove Dir.glob("*#{@config.text_log_extension}")
    end
    
    def setup
        puts "Setup..."
        
        FileUtils.mkdir_p(@log_dir) unless File.exists?(@log_dir)
    end
    
    def build
        @teams.each do |team|
            if FileTest.exists? "#{team}/build"
                puts "Building team #{team}..."
                
                check_file "#{team}/build", true

                threads = []
                
                @config.hosts.each do |host|
                    threads << build_on_host(team, host)
                end

                threads.each { |thread| thread.join }
            end
        end
    end

    def build_on_host team, host
       Thread.new do
           system "ssh #{host} '#{team}/build #{team}' >> #{@log_dir}/build_#{host}.log 2>> #{@log_dir}/build_#{host}.log"
       end
    end
    
    def teardown
        puts "Teardown..."
    end
    
    def results
        puts "Updating scoreboard..."
        
        results = Results.new @results_csv, @config
        results.write_file @results_xml, "xml"
    end
end

class SingleMatch < Tournament
    def initialize arguments
        team1 = arguments.shift.chomp("/")
        team2 = arguments.shift.chomp("/")
        server_conf = arguments.shift
        player_conf = arguments.shift
        
        raise "First team unspecified." if team1.nil?
        raise "Second team unspecified." if team2.nil?
        
        create_config team1, team2, server_conf, player_conf
        run
    end
    
    def create_config team1, team2, server_conf, player_conf
        @mode = "mode_single_match"
        @teams = [team1, team2]
        
        @sleep_time = 0
        @server_conf = server_conf
        @player_conf = player_conf
        
        configure_logging
    end
end

class SimulateTournament < Tournament
    def initialize config
        @simulate_match_index = 0
        super config
    end
    
    def setup
    end

    def cleanup
    end

    def teardown
    end

    def build
        puts "Ignoring build in simulation mode."
    end

    def start_match team1, team2
        @simulate_match_index = @simulate_match_index + 1
        puts "%4d: %s vs %s" % [@simulate_match_index, team1, team2]
    end
end

class ResumeTournament < Tournament
    def initialize config
        @resume_match_index = 0
        super config
    end
    
    def configure_logging
        @log_dir = Time.now.strftime @config.log_dir
        @results_csv = File.join @log_dir, "results.log"
        @results_xml = File.join @log_dir, "results.xml"
        
        raise "Resume directory '#{@log_dir}' not found." unless FileTest.directory? @log_dir
        puts "Resuming tournament from #{@log_dir}."
        
        @results_saved = ResumeResults.new @results_csv
    end
    
    def start_match team1, team2
        @resume_match_index = @resume_match_index + 1
        
        if FileTest.exists? Match.current_match_dir(@log_dir)
            puts "Skipping match #{@resume_match_index}."
            
            @results_saved.write_next_results_line
            Match.increment_match_index
            results
        else
            puts "Resuming match #{@resume_match_index}."
            
            super team1, team2
        end
    end
end

def print_usage
    puts "Start tournament from configuration file: ./start.sh --config=<file>"
    puts "Resume aborted tournament: ./start.sh --config=<file> --resume --log_dir=<directory>"
end

begin
    config = Config.new DEFAULTS_FILE

    if config.simulate
        SimulateTournament.new config
    elsif config.resume
        ResumeTournament.new config
    else	
        Tournament.new config
    end
rescue Interrupt
    puts "Aborted."
rescue RuntimeError => exc
    puts "Error: #{exc}"
    puts exc.backtrace if SHOW_EXCEPTION_BACKTRACE
end
