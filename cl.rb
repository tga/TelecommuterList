#!/usr/bin/env ruby

#
# This can be run like so:
#
# ruby cl.rb sof > sof_posts.html
#

require 'rubygems'
require 'nokogiri'
require 'httpclient'

$seen_urls   = Hash.new
$seen_titles = Hash.new
section      = ARGV[0]

def generate_results(url, link)
  base_href = url.match(/^http:\/\/.+\.craigslist.\w+/)[0]
  begin
    search_results = Nokogiri::HTML(HTTPClient.get_content(url))
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
      if !$seen_urls[real_link] && !$seen_titles[post_link.content]
        puts '<p>' + date + ' - ' + '<a href="' + real_link + '">' + post_title + '</a> [' + link.content + ']</p>'
        $seen_urls[real_link] = true
        $seen_titles[post_link.content] = true
      end
    end
  rescue SocketError => socket_error
    STDERR.puts "ERROR: Couldn't read " + url
  #rescue OpenURI::HTTPError
  #  STDERR.puts 'ERROR: 404 on ' + url
  end
end

page = Nokogiri::HTML(HTTPClient.get_content('http://craigslist.org'))

i = 0
page.search('td').each do |td|
  if i > 10 && i < 19
    td.search('a').each do |link|
      href = link.attributes['href'].to_s
      if href =~ /^http:\/\/geo/
        geo_page_head = HTTPClient.head(href).header
        if geo_page_head.status_code == 200
          geo_page = Nokogiri::HTML(HTTPClient.get_content(href))
          geo_page.search('//div/a').each do |geo_link|
            url = geo_link.attributes['href'].to_s + 'search/sof?query=&catAbbreviation=' + section + '&addOne=telecommuting'
            generate_results(url, link)
            #sleep 1
          end
        else
          url = geo_page_head['Location'][0] + '/search/sof?query=&catAbbreviation=' + section + '&addOne=telecommuting'
          generate_results(url, link)
          #sleep 1
        end
      else
if false
        url = href + 'search/sof?query=&catAbbreviation=' + section + '&addOne=telecommuting'
        generate_results(url, link)
        #sleep 1
end
      end
    end
  end
  i+=1
end

STDERR.puts 'Total of ' + $seen_titles.length.to_s + ' unique records found.'
