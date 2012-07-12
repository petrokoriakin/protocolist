module Protocolist

  module NormalizationMethods

    def normalize_options activity_type, options
      fires_on = Array(options[:on] || activity_type)

      data_proc = if options[:data].respond_to?(:call)
                    lambda{|record| options[:data].call(record)}
                  elsif options[:data].class == Symbol
                    lambda{|record| record.send(options[:data]) }
                  else
                    lambda{|record| options[:data] }
                  end

      options_for_callback = options.select{|k,v| [:if, :unless].include? k }

      options_for_fire = options.reject{|k,v| [:if, :unless, :on].include? k }
      [fires_on, data_proc, options_for_callback, options_for_fire]
    end

  end

  module InstanceMethods

    def fire activity_type, options={}
      options[:target] = self if options[:target] == nil
      options[:target] = nil if options[:target] == false

      Protocolist.fire activity_type, options
    end

  end

  module ActiveRecordModelAdditions

    def self.included base
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods

      include  NormalizationMethods

      def fires activity_type, options={}
        fires_on, data_proc, options_for_callback, options_for_fire = normalize_options activity_type, options
        callback_proc = lambda{|record|
          record.fire activity_type, options_for_fire.merge({:data => data_proc.call(record)})
        }

        fires_on.each do |on|
          send("after_#{on.to_s}".to_sym, callback_proc, options_for_callback)
        end
      end
    end

  end

  module MongoidModelAdditions

    def self.included base
      base.extend ClassAdditions
      base.send :include, InstanceMethods
    end

    module ClassAdditions

      include NormalizationMethods

      def fires activity_type, options={}
        fires_on, data_proc, options_for_callback, options_for_fire = normalize_options activity_type, options

        fires_on.each do |on|
          method_name = :"fire_#{activity_type}_after_#{on}"
          define_method(method_name) do
            fire activity_type, options_for_fire.merge({:data => data_proc.call(self)})
          end
          send(:"after_#{on}".to_sym, method_name, options_for_callback)
        end
      end
    end

  end

end
