module Fluent
  require "json"

  class GELFOutput < BufferedOutput
    Plugin.register_output("gelf", self)

    config_param :host, :string, :default => nil
    config_param :port, :integer, :default => 12201
    config_param :protocol, :string, :default => "udp"

    def initialize
      super
      require "gelf"
      require "date"
    end

    def configure(conf)
      super

      # a destination hostname or IP address must be provided
      raise ConfigError, "'host' parameter (hostname or address of Graylog2 server) is required" unless conf.has_key?("host")

      # choose protocol to pass to gelf-rb Notifier constructor
      # (@protocol is used instead of conf['protocol'] to leverage config_param default)
      if @protocol == "udp" then @proto = GELF::Protocol::UDP elsif @protocol == "tcp" then @proto = GELF::Protocol::TCP else raise ConfigError, "'protocol' parameter should be either 'udp' (default) or 'tcp'" end
    end

    def start
      super

      @conn = GELF::Notifier.new(@host, @port, "WAN")

      # Errors are not coming from Ruby so we use direct mapping
      @conn.level_mapping = "direct"
      # file and line from Ruby are in this class, not relevant
      @conn.collect_file_and_line = false
    end

    def shutdown
      super
    end

    def format(tag, time, record)
      parsed_log =
        begin
          record.merge(JSON.parse(record["log"])).reject { |k| k == "log" }
        rescue
          record
        end

      required_fields = {
        :timestamp => get_time(parsed_log, time),
        :host => get_host(parsed_log),
        :version => "1.1",
        :short_message => parsed_log["msg"] || parsed_log["message"] || parsed_log["log"] || "[none]",
      }

      stripped_log = parsed_log.reject { |k| k == "log" || k == "msg" || k == "time" }

      flattened_log = flatten_hash(stripped_log)

      flattened_log.merge(required_fields).to_msgpack
    end

    def get_host(record)
      record["hostname"] || record["name"] || (record["kubernetes"] ? record["kubernetes"]["pod_name"] : "unknown")
    end

    def get_time(record, default_time)
      begin
        json_log_time_s = record["time"].to_s

        if /^\d{4}-\d{2}-\d{2}/ =~ json_log_time_s
          DateTime.parse(json_log_time_s).to_time.to_f
        elsif /^\d{10}$/ =~ json_log_time_s
          json_log_time_s.to_f
        elsif /^\d{13}$/ =~ json_log_time_s
          "#{json_log_time_s[0..9]}.#{json_log_time_s[10..12]}".to_f
        else
          DateTime.parse(json_log_time_s).to_time.to_f
        end
      rescue
        default_time
      end
    end

    def write(chunk)
      chunk.msgpack_each do |data|
        @conn.notify!(data)
      end
    end

    def flatten_hash(hash, recursive_key = "", separator = "_")
      hash.each_with_object({}) do |(k, v), ret|
        key = recursive_key + k.to_s
        if v.is_a? Hash
          ret.merge! flatten_hash(v, key + separator)
        else
          ret[key] = v
        end
      end
    end
  end
end
