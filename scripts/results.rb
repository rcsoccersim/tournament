require 'time'
require 'yaml'

WIN_POINTS = 3
LOSE_POINTS = 0
DRAW_POINTS = 1

class Array
    def to_xml
        collect { |item| item.to_xml }.join
    end
end

class Team
    attr_reader :name, :coach, :team_dir, :country, :won, :drawn, :lost, :goals_scored, :goals_received
    
    def initialize name, coach, match_config
        @name = name
        @coach = coach
        @country = match_config["country"]
        @team_dir = match_config["team_dir"] 
        @won = 0
        @drawn = 0
        @lost = 0
        @goals_scored = 0
        @goals_received = 0
    end
    
    def win
        @won = @won + 1
    end
    
    def lose
        @lost = @lost + 1
    end
    
    def draw
        @drawn = @drawn + 1
    end
    
    def match goals_scored, goals_received
        if goals_scored > goals_received
            win
        elsif goals_scored < goals_received
            lose
        else
            draw
        end
        
        @goals_scored = @goals_scored + goals_scored
        @goals_received = @goals_received + goals_received
    end
    
    def matches
        won + drawn + lost
    end
    
    def points
        won * WIN_POINTS + drawn * DRAW_POINTS + lost * LOSE_POINTS
    end
    
    def goal_diff
        goals_scored - goals_received
    end
    
    def avg_goal_diff
        matches > 0 ? goal_diff.to_f / matches : 0.0
    end
    
    def avg_goals_scored
        matches > 0 ? goals_scored.to_f / matches : 0.0
    end
    
    def to_s
        "%-16s %3d %3d %3d %3d %6.2f %6.2f" % [name, matches, points, goals_scored, goals_received, avg_goal_diff, avg_goals_scored]
    end
    
    def to_xml
        "<score>
          #{name_to_xml}
          <matches>#{matches}</matches>
          <points>#{points}</points>
          <won>#{@won}</won>
          <drawn>#{@drawn}</drawn>
          <lost>#{@lost}</lost>
          <goals_scored>#{goals_scored}</goals_scored>
          <goals_received>#{goals_received}</goals_received>
          <avg_goal_diff>#{avg_goal_diff}</avg_goal_diff>
          <avg_goals_scored>#{avg_goals_scored}</avg_goals_scored>
        </score>"
    end
    
    def name_to_xml
        "<team>
          <teamname>#{name}</teamname>
          <country>#{@country}</country>
          <dir>#{@team_dir}</dir>
        </team>"
    end
    
    def name_with_coach
        coach.nil? ? @name : "#{@name}_#{@coach}"
    end
    
    def == other
        @team_dir == other
    end
    
    def <=> other
        return other.points <=> points unless points == other.points
        return other.goal_diff <=> goal_diff unless goal_diff == other.goal_diff
        other.goals_scored <=> goals_scored
    end
end

class MatchResult
    
    def initialize index, team_l, team_r, log_dir, result, config, match_config
        @index = index
        @team_l = team_l
        @team_r = team_r
        @result = result
        @config = config
        @match_config = match_config
        
        if @result.penalty?
            team_l.match @result.team_l_score + @result.team_l_penalty_score, @result.team_r_score + @result.team_r_penalty_score
            team_r.match @result.team_r_score + @result.team_r_penalty_score, @result.team_l_score + @result.team_l_penalty_score
        else
            team_l.match result.team_l_score, result.team_r_score
            team_r.match result.team_r_score, result.team_l_score
        end
    end
    
    def match_dir
        "match_#{@index}"
    end

    def penalty?
        @result.penalty?
    end

    def statistics?
        @match_config['statistics']
    end

    def scoreboard?
        @match_config['scoreboard']
    end

    def robocup2flash?
        @match_config['robocup2flash']
    end

    def time_s
        @result.time.strftime '%Y%m%d%H%M'
    end
    
    def time_readable
        @result.time.strftime '%Y-%m-%d %H:%M'
    end
    
    def team_score team, team_score, team_penalty_score
        (team.name.nil? ? 'null' : "#{team.name_with_coach}_#{team_score}" + (penalty? ? "_#{team_penalty_score}" : ""))
    end
    
    def gamelog_filename
        File.join match_dir, "%s-%s-vs-%s" % [time_s, team_score(@team_l, @result.team_l_score, @result.team_l_penalty_score), team_score(@team_r, @result.team_r_score, @result.team_r_penalty_score)]
    end
    
    def rcg_filename
        "#{gamelog_filename}#{@config.game_log_extension}"
    end
    
    def rcl_filename
        "#{gamelog_filename}#{@config.text_log_extension}"
    end

    def swf_filename
        File.join match_dir, "match_#{@index}.swf"
    end
        
    def output_log_filename name
        "#{match_dir}/#{name}-output.log"
    end
    
    def error_log_filename name
        "#{match_dir}/#{name}-error.log"
    end
    
    def statistics_filename
        @match_config['statistics'] ? File.join(match_dir, "statistics.xml") : "no"
    end
    
    def exception name
        @match_config[name]['exception'] ? "yes" : "no"
    end
    
    def to_s
        "%s %-16s vs %-16s %2d : %2d" % [time_s, @team_l.name, @team_r.name, @result.team_l_score, @result.team_r_score]
    end
    
    def to_xml
        "<match>
          <time>#{time_readable}</time>
          <penalty>#{@result.penalty? ? 'yes' : 'no'}</penalty>
          <team_l>
            #{@team_l.name_to_xml}
            <score>#{@result.team_l_score}</score>
            <penalty_taken>#{@result.team_l_penalty_taken}</penalty_taken>
            <penalty_score>#{@result.team_l_penalty_score}</penalty_score>
            <output>#{output_log_filename('team_l')}</output>
            <error>#{error_log_filename('team_l')}</error>
            <exception>#{exception('team_l')}</exception>
          </team_l>
          <team_r>
            #{@team_r.name_to_xml} 
            <score>#{@result.team_r_score}</score>
            <penalty_taken>#{@result.team_r_penalty_taken}</penalty_taken>
            <penalty_score>#{@result.team_r_penalty_score}</penalty_score>
            <output>#{output_log_filename('team_r')}</output>
            <error>#{error_log_filename('team_r')}</error>
            <exception>#{exception('team_r')}</exception>
          </team_r>
          <server>
            <rcg>#{rcg_filename}</rcg>
            <rcl>#{rcl_filename}</rcl>
            <swf>#{swf_filename}</swf>
            <output>#{output_log_filename('server')}</output>
            <error>#{error_log_filename('server')}</error>
            <statistics>#{statistics_filename}</statistics>
          </server>
        </match>"
    end
end

class Results
    
    def initialize results_file, config
        @results_file = results_file
        @config = config
        @log_dir = File.dirname results_file
        @teams = []
        @matches = []
        
        raise "Results file not written by server." unless FileTest.exists? results_file
        
        File.open(results_file) do |file|
            result_lines = file.readlines
            result_lines.shift
            
            analyse result_lines
        end
        
        rank
    end
    
    def find_team team_name, team_coach, match_config
        team_dir = match_config["team_dir"]
        
        @teams << Team.new(team_name, team_coach, match_config) unless @teams.include? team_dir
        @teams.find { |team| team.team_dir == team_dir }
    end
    
    def analyse results
        results.each_with_index do |line, index|
            csv_results = CSVResult.new line
            match_config = YAML::load_file File.join(@log_dir, "match_#{index + 1}", "match.yml")
            
            team_l = find_team csv_results.team_l_name, csv_results.team_l_coach, match_config['team_l']
            team_r = find_team csv_results.team_r_name, csv_results.team_r_coach, match_config['team_r']
            
            @matches << MatchResult.new(index + 1, team_l, team_r, @log_dir, csv_results, @config, match_config)
        end
    end
    
    def rank
        @teams = @teams.sort { |team1, team2| team1 <=> team2 }
    end
    
    def write_file filename, format
        File.open(filename, "w") { |file| write_stream file, format }
    end
    
    def write_stream stream, format
        format_method = "write_format_#{format}"
        raise "Unknown output format specified." unless respond_to? format_method
        send format_method, stream
    end
    
    def write_format_xml stream
        stream.puts to_xml
    end
    
    def write_format_s stream
        stream.puts to_s
    end
    
    def to_xml
        "<?xml version=\"1.0\" encoding=\"utf-8\" ?>
        <?xml-stylesheet type=\"text/xsl\" href=\"#{@config.stylesheet_url}\" ?>
        <results>
          <title>#{@config.title}</title>
          <penalty>#{penalty? ? 'yes' : 'no'}</penalty>
          <statistics>#{statistics? ? 'yes' : 'no'}</statistics>
          <robocup2flash>#{robocup2flash? ? 'yes' : 'no'}</robocup2flash>
          <scoreboard show=\"#{scoreboard? ? 'yes' : 'no'}\">
            #{@teams.to_xml}
          </scoreboard>
          <matches>
            #{@matches.to_xml}
          </matches>
        </results>"
    end
    
    def to_s
        "#{[scoreboard_to_s, matches_to_s].join '\n'}"
    end
    
    def scoreboard_to_s
        scoreboard = []
        
        @teams.each_with_index do |team, index|
            scoreboard << "%3d %s" % [index + 1, team.to_s]
        end
        
        "---
        Score Board:
        [index, name, matches, points, goals_scored, goals_received, avg_goal_diff, avg_goals_scored]
        #{scoreboard.join '\n'}"
    end
    
    def matches_to_s
        matches = []
        
        @matches.each_with_index do |match, index|
            matches << "%3d %s" % [index + 1, match.to_s]
        end
        
        "---
        Matches:
        [index, time, team_l.name, team_r.name, team_l_score, team_r_score]
        #{matches.join '\n'}"
    end
    
    def penalty?
        @matches.select { |match| match.penalty? }.size > 0
    end
    
    def statistics?
        @matches.select { |match| match.statistics? }.size > 0
    end

    def robocup2flash?
        @matches.select { |match| match.robocup2flash? }.size > 0
    end

    def scoreboard?
        @matches.select { |match| match.scoreboard? }.size > 0
    end
end

class ResumeResults
    
    def initialize results_file
        @results_file = results_file
        FileUtils.cp results_file, "#{results_file}.original"
        
        File.open(results_file) do |file|
            @result_lines = file.readlines
            @header_line = @result_lines.shift
        end
        
        write_header_line
    end
        
    def write_header_line
        File.open(@results_file, "w") { |file| file.puts @header_line }
    end
    
    def write_next_results_line
        File.open(@results_file, "a") { |file| file.puts @result_lines.shift }
    end
    
    def result_count
        @result_lines.size
    end
end

class CSVResult
    
    attr_reader :time,
        :team_l_name, :team_r_name,
        :team_l_coach, :team_r_coach,
        :team_l_score, :team_r_score,
        :team_l_penalty_taken, :team_r_penalty_taken,
        :team_l_penalty_score, :team_r_penalty_score,
        :cointoss
    
    def initialize result_line
        result = result_line.split(", ")
        
        @time = parse_time result[0]
        @team_l_name = parse_string result[1]
        @team_r_name = parse_string result[2]
        @team_l_coach = parse_string result[3]
        @team_r_coach = parse_string result[4]
        @team_l_score = parse_int result[5]
        @team_r_score = parse_int result[6]
        @team_l_penalty_taken = parse_int result[7]
        @team_r_penalty_taken = parse_int result[8]
        @team_l_penalty_score = parse_int result[9]
        @team_r_penalty_score = parse_int result[10]
        @cointoss = nil
    end
    
    def parse_string value
        value =~ /\".*\"/ ? value[1..-2] : nil
    end
    
    def parse_int value
        value == "NULL" ? 0 : value.to_i
    end
    
    def parse_time value
        Time.parse value
    end
    
    def penalty?
        @team_l_penalty_taken > 0 or @team_r_penalty_taken > 0
    end
end
