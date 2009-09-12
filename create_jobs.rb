#!/usr/bin/env ruby
require 'rubygems'
require 'activerecord'

class CreateJobs < ActiveRecord::Migration
  def self.up
    create_table :jobs do |t|
      t.string :geo
      t.string :section
      t.string :href
      t.string :title
      t.datetime :posted_at
    end

    add_index :jobs, :href
    add_index :jobs, :posted_at
    add_index :jobs, :geo
    add_index :jobs, :section
  end

  def self.down
    drop_table :jobs
  end
end

if __FILE__ == $0
  ActiveRecord::Base.establish_connection(YAML.load(File.read('database.yml')))
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  CreateJobs.migrate(:up)
end
