require 'rails/generators/active_record'

module LpResettable
  module Generators
    class ModelGenerator < ActiveRecord::Generators::Base
      desc 'Creates an LpResettable migration for the specified model.'

      def self.source_root
        @source_root ||= File.expand_path('../templates', __FILE__)
      end

      def generate_migration
        migration_template 'migration.rb.erb', "db/migrate/#{migration_file_name}"
      end

      def migration_name
        "add_lp_resettable_to_#{name.underscore.pluralize}"
      end

      def migration_file_name
        "#{migration_name}.rb"
      end

      def migration_class_name
        if Rails::VERSION::MAJOR >= 5
          "ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        else
          'ActiveRecord::Migration'
        end
      end
    end
  end
end
