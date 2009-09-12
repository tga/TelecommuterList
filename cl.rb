#!/usr/bin/env ruby

def usage
<<-EOS
NAME
  cl.rb - Craigslist spider for remote jobs

SYNOPSIS

  ruby cl.rb sof > sof_posts.html

DESCRIPTION

  A craigslist spider created by reddit user jdunn that collects
  telecommuter jobs from all over the world.

OPTIONS

  --usage, -h
    Prints this message

  --verbose, -v
    Progress is printed to STDERR

  --database, -d
    Instead of printing records to STDOUT, insert them into the database
    specified by the database.yml file
EOS
end

require 'rubygems'
require 'nokogiri'
require 'httpclient'

class TelecommuterList
  def initialize(section, options)
    raise "Specify a section of craigslist to parse, eg. med, sad, sof, tch, web" if section.nil? || section.empty?
    @seen_urls   = Hash.new
    @seen_titles = Hash.new
    @section     = section
    @options     = options
    establish_db_connection if @options[:database]
  end

  def crawl
    geo_page_root = crawl_page('http://craigslist.org')
    i = 0

    # This collects all of the city links (and possibly some menu links)
    # from the root craigslist page, and passes them to the geo-page parser
    geo_page_root.search('td').each do |td|
      td.search('a').each { |link| parse_geo(link) } if i > 10 && i < 19
      i+=1
    end
    STDERR.puts 'Total of ' + @seen_titles.length.to_s + ' unique records found.' if @options[:verbose]
  end

  private
  def establish_db_connection
    TelecommuterList.send :include, DbMethods
  end

  def crawl_page(href)
    Nokogiri::HTML(HTTPClient.get_content(href))
  end

  def generate_results(url, link)
    base_href = url.match(/^http:\/\/.+\.craigslist.\w+/)[0]
    begin
      search_results = crawl_page(url)
      search_results.search('p').each do |p|
        d_parts = p.content.match(/^\s*(\w+)\s+(\d+)\s+/)
        if d_parts.nil?
          date = '???'
        else
          date = d_parts[1] + ' ' + d_parts[2]
        end
        post_link = p.search('a').first
        post_title = post_link.content.match(/(.+)\s+-\s*$/)[1]
        if post_link.attributes['href'].to_s[0,1] == '/'
          real_link = base_href + post_link.attributes['href']
        else
          real_link = post_link.attributes['href']
        end
        if !@seen_urls[real_link] && !@seen_titles[post_link.content]
          puts '<p>' + date + ' - ' + '<a href="' + real_link + '">' + post_title + '</a> [' + link.content + ']</p>'
          @seen_urls[real_link] = true
          @seen_titles[post_link.content] = true
        end
      end
    rescue SocketError => socket_error
      STDERR.puts "ERROR: Couldn't read " + url
      #rescue OpenURI::HTTPError
      #  STDERR.puts 'ERROR: 404 on ' + url
    end
  end

  def parse_geo(link)
    href = link.attributes['href'].to_s
    if href =~ /^http:\/\/geo/
      geo_page_head = HTTPClient.head(href).header
      if geo_page_head.status_code == 200
        geo_page = crawl_page(href)
        geo_page.search('//div/a').each do |geo_link|
          url = geo_link.attributes['href'].to_s + 'search/sof?query=&catAbbreviation=' + @section + '&addOne=telecommuting'
          generate_results(url, link)
          #sleep 1
        end
      else
        url = geo_page_head['Location'][0] + '/search/sof?query=&catAbbreviation=' + @section + '&addOne=telecommuting'
        generate_results(url, link)
        #sleep 1
      end
    else
      if false
        url = href + 'search/sof?query=&catAbbreviation=' + @section + '&addOne=telecommuting'
        generate_results(url, link)
        #sleep 1
      end
    end
  end

end

module DbMethods
  require 'activerecord' # TGA says: This is big - hence conditional include
  ActiveRecord::Base.establish_connection(YAML.load(File.read('database.yml')))
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  class Job < ActiveRecord::Base
  end
end

if __FILE__ == $0
  require 'getoptlong'
  args = [["--verbose", "-v", GetoptLong::NO_ARGUMENT],
          ["--usage",   "-h", GetoptLong::NO_ARGUMENT],
          ["--database", "-d", GetoptLong::NO_ARGUMENT]
         ]

  options = {}
  GetoptLong.new(*args).each do |opt, arg|
    case opt
    when "--usage" then puts usage; exit(0);
    when "--verbose" then options[:verbose] = true
    when "--database" then options[:database] = true
    end
  end
  if ARGV.size < 1 then puts usage; exit(0); end

  spider = TelecommuterList.new(ARGV[0], options)
  spider.crawl
end
