require 'yaml'
require 'pp'

class Config
    def initialize defaults_filename
        @config = YAML::load_file defaults_filename
        @config['config'] = nil
        
        ARGV.each { |arg| load_user_config_from_yaml($1) if arg=~ /^--config=(.+)$/ }
        ARGV.each { |arg| parse_arg arg }
    end
    
    def load_user_config_from_yaml config_filename
        user_config = YAML::load_file config_filename
        
        user_config.each_pair do |key, value|
            raise "Unknown config parameter '#{key}'." unless @config.has_key? key
            @config[key] = value
        end
    end
    
    def parse_arg arg
        return add_config_from_arg($1, 'yes') if arg =~ /^--([a-z_]+)$/
        return add_config_from_arg($1, 'no') if arg =~ /^--no-([a-z_]+)$/
        return add_config_from_arg($1, $2) if arg =~ /^--([a-z_]+)=(.+)$/
        
        raise "Unrecognized command line argument '#{arg}'."
    end
    
    def add_config_from_arg key, value
        raise "Unknown config parameter '#{key}'." unless @config.has_key? key
        
        value = value.gsub(/,/, ', ')
        data = YAML::load("---\n#{key}: #{value}")
        @config[key] = data[key]
    end
    
    def method_missing method
        raise "Config parameter '#{method}' unspecified." unless @config.has_key? method.id2name
        @config[method.id2name]
    end
    
    def to_s
        @config.pretty_inspect
    end
end
