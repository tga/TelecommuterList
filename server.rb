#!/usr/bin/env ruby
#
# Usage
#   camping server.rb
#
# Make sure that gem/bin is in your execute path
#
require 'rubygems'
require 'camping'

Camping.goes :Joblist

db = YAML.load(File.read('database.yml'))
Joblist::Models::Base.establish_connection(db)

module Joblist::Models
  class Job < ActiveRecord::Base
    def self.table_name_prefix; ""; end
  end
end

module Joblist::Controllers
  class Index
    def get
      @now = DateTime.new(Time.now.year, Time.now.month, Time.now.day)
      @today = Job.find(:all, :conditions => {:posted_at => @now})
      @yesterday = Job.find(:all, :conditions => {:posted_at => @now - 1.day})
      @daybefore = Job.find(:all, :conditions => {:posted_at => @now - 2.days})
      render :index
    end
  end
end

module Joblist::Views
  def layout
    html do
      head { title "Telecommuter Jobs On Craigslist" }
      body do
        h1 "Telecommuter Jobs On Craigslist"
        self << yield
      end
    end
  end
  
  def job_row(job)
    tr do
      td { p job.section }; td { p job.geo }; 
      td { a job.title, :href => job.href }
    end
  end

  def job_table(title, jobs)
    h2 title
    table do
      for job in jobs
        job_row(job)
      end
    end
  end

  def index
    job_table("Today", @today)
    job_table("Yesterday", @yesterday)
    job_table("The day before Yesterday", @daybefore)
  end
end
