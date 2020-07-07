require 'util'

require 'fileutils'

class Match
    @@match_index = 1
    
    def initialize team_l, team_r, results_csv, tournament_log_dir, config
        @team_l = team_l
        @team_l_config = YAML::load_file File.join(team_l, "team.yml")
        @team_r = team_r
        @team_r_config = YAML::load_file File.join(team_r, "team.yml")
        @results = results_csv
        @log_dir = Match.current_match_dir tournament_log_dir
        @config = config
    end
    
    def setup
        FileUtils.mkdir @log_dir
    end
    
    def make_start_scripts
        make_team_start_script "l", @team_l
        make_team_start_script "r", @team_r
    end
    
    def make_team_start_script side, team
        script = "team_#{side}_start.sh"
        
        File.open(script, "w") do |file|
            file.puts "#!/bin/sh"
            
            Range.parse(@config.agent_range).each do |num|
                file.puts "ssh -f #{get_host(side, num)} #{team}/start #{@config.server} #{team} #{num} #{@config.team_mode} >> #{@log_dir}/team_#{side}-output.log 2>> #{@log_dir}/team_#{side}-error.log"
                file.puts "sleep #{@config.agent_sleep * (num == 1 ? 2 : 1)}"
            end
        end
        
        FileUtils.chmod 0755, script
    end
    
    def get_host side, num
        hosts = (side == "l" ? hosts_left : hosts_right)
        hosts[num % hosts.size]
    end
    
    def hosts_left
        @config.hosts[0...(@config.hosts.size / 2)]
    end
    
    def hosts_right
        @config.hosts[(@config.hosts.size / 2)...@config.hosts.size]
    end
    
    def cleanup
        FileUtils.remove Dir.glob("team_?_start.sh")
    end
    
    def start_rcssserver
        include = []
        include << "include=#{@config.server_conf}" unless @config.server_conf.nil?
        include << "include=#{@config.player_conf}" unless @config.player_conf.nil?
        
        system "#{@config.rcssserver_bin} server::team_l_start = './team_l_start.sh' server::team_r_start = './team_r_start.sh' CSVSaver::save='true' CSVSaver::filename='#{File.join(Dir.pwd, @results)}' #{include.join(' ')} > #{@log_dir}/server-output.log 2> #{@log_dir}/server-error.log"
    end
    
    def stop_teams
        puts "Waiting for teams to shutdown..."
        
        sleep @config.shutdown_sleep
        
        hosts_left.each do |host|
            system "ssh #{host} '#{@team_l}/kill' >> #{@log_dir}/team_l-output.log 2>> #{@log_dir}/team_l-error.log"
        end
        
        hosts_right.each do |host|
            system "ssh #{host} '#{@team_r}/kill' >> #{@log_dir}/team_r-output.log 2>> #{@log_dir}/team_r-error.log"
        end
    end
    
    def save_results
        puts "Saving server log files..."
        
        FileUtils.move Dir.glob("*#{@config.game_log_extension}"), @log_dir
        FileUtils.move Dir.glob("*#{@config.text_log_extension}"), @log_dir
    end
    
    def convert_results
        puts "Converting server log files..."
        
        rcg_v3_filename = File.join @log_dir, "match_#{@@match_index}_v3.rcg"
        swf_filename = File.join @log_dir, "match_#{@@match_index}.swf"
        
        system "#{@config.rcgverconv_bin} #{@log_dir}/*#{@config.game_log_extension} --version 3 --output #{rcg_v3_filename} >> #{@log_dir}/server-output.log 2>> #{@log_dir}/server-error.log"
        system "#{@config.robocup2flash_bin} #{rcg_v3_filename} #{swf_filename} >> #{@log_dir}/server-output.log 2>> #{@log_dir}/server-error.log"
        system "#{@config.gzip_bin} #{rcg_v3_filename}"
    end
    
    def save_logging side, team
        if FileTest.exists? File.join(team, "save_logging")
            puts "Saving log files for team #{team}..."
        
            (side == "l" ? hosts_left : hosts_right).each do |host|
                Range.parse(@config.agent_range).each do |num|
                    system "ssh #{host} '#{team}/save_logging #{@config.server} #{team} #{num} #{host} #{File.join(Dir.pwd, @log_dir)} #{@config.team_mode}' >> #{@log_dir}/team_#{side}-output.log 2>> #{@log_dir}/team_#{side}-error.log"
                end
            end
        end
    end
    
    def statistics
        puts "Generating match statistics... [Press ctrl+c to abort.]"
        
        current_working_dir = Dir.pwd
        log_dir_absolute = File.join current_working_dir, @log_dir
        Dir.chdir @config.statistics_dir
        system "#{@config.statistics_bin} #{log_dir_absolute}/ >> #{log_dir_absolute}/server-output.log 2>> #{log_dir_absolute}/server-error.log"
        Dir.chdir current_working_dir
    end
    
    def parse_exceptions filename
        return true unless File.exists? filename
        
        File.open(filename) do |file|
            file.readlines.each do |line|
                @config.exception_patterns.each do |pattern|
                    return true if line =~ Regexp.new(pattern)
                end
            end
        end
        
        false
    end
    
    def write_configuration filename
        configuration = {
            "team_l" => @team_l_config.merge({ "team_dir" => @team_l, "exception" => parse_exceptions("#{@log_dir}/team_l-error.log") }), 
            "team_r" => @team_r_config.merge({ "team_dir" => @team_r, "exception" => parse_exceptions("#{@log_dir}/team_r-error.log") }),
            "statistics" => @config.statistics,
            "scoreboard" => @config.show_scoreboard,
            "robocup2flash" => @config.robocup2flash
        }
        
        File.open(filename, "w") { |file| file.write(configuration.to_yaml) }
    end
    
    def start
        setup
        make_start_scripts
        start_rcssserver
        stop_teams
        write_configuration File.join(@log_dir, "match.yml")
        save_results
        convert_results if @config.robocup2flash
        save_logging "l", @team_l if @config.save_logging
        save_logging "r", @team_r if @config.save_logging
        statistics if @config.statistics
        cleanup
        Match.increment_match_index
    end
    
    def Match.current_match_dir tournament_log_dir
        File.join tournament_log_dir, "match_#{@@match_index}"
    end
    
    def Match.current_match_index
        @@match_index
    end
    
    def Match.increment_match_index
        @@match_index = @@match_index + 1
    end
end
