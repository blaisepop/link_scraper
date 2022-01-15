require 'nokogiri'
require 'open-uri'
require 'csv'
require "tty-prompt"
prompt = TTY::Prompt.new
user_choice = prompt.select("Which type of broken link would you like to find?", %w(Internal External))
@filepath = "#{user_choice} links #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}.csv"
@csv_options = { col_sep: ',', force_quotes: true, quote_char: '"' }
source = 'input.csv'
@excluded_domains = %w[
    facebook.com
    linkedin.com
    twitter.com
    pinterest.com
    instagram.com
    google.com
    microsoft.com
    anibis.ch
    youtube.com
    immoscout24.ch
    jobs.ch
    illustre.ch
    scout24.ch
    abo.blick.ch
    deindeal.ch
    autoscout24.ch
    ringier-advertising.ch
    energy.ch
    gate24.ch
    wordpress.org
    api.whatsapp.com
    sbb.ch
    tripadvisor.mediaroom.com
    tripadvisorsupport.com
    addtoany.com
    impactmedias.ch
    youtu.be
    goo.gl
    docs.google.com
    google.de
    ticketcorner.ch
    tools.gratiszeitungen.ch
  ]

def external_bl_scraper(starting_url)
  begin
      html_file = open(starting_url).read
      html_doc = Nokogiri::HTML(html_file)
      domain = URI.parse(starting_url).host.sub(/^www./,'')
      nodeset = html_doc.xpath('//a')
  rescue
    puts "Issue with origin link #{starting_url}"
  else
    nodeset.map {|element| element["href"]}.compact
    nodeset.each do |link|
      link_anchor = link.text
      link = link['href']
      if link != nil && link.start_with?("http")
        url = URI.parse(link)
        link_domain = url.host.sub(/^www./,'')
        if link_domain != domain
          unless @excluded_domains.include? link_domain
            req = Net::HTTP.new(url.host, url.port)
            if link.start_with?("https")
              req.use_ssl = true
            elsif
              req.use_ssl = false
            end
            res = req.request_head("#{url.path}/")
            res = res.code
            puts "Current link #{link}, code #{res}"
          end
        end
      else
      end
    rescue Net::ReadTimeout
      puts "Timeout on #{link}"
   rescue Net::OpenTimeout
      puts "Open Timeout on #{link}"
    rescue OpenSSL::SSL::SSLError
      puts "SSL error on #{link}"
    rescue RuntimeError
      puts "RuntimeError"
    rescue Errno::ECONNRESET
      puts "Erno"
    rescue URI::InvalidURIError
       puts "Invalid error"
     rescue NoMethodError
       puts "No external link found on #{starting_url}"
     rescue SocketError
       puts "Found one on #{starting_url} : #{link}!"
      CSV.open(@filepath,'a', @csv_options) do |csv|
         csv << [domain,starting_url,link_anchor,link]
       end
    rescue Errno::ECONNREFUSED
      puts "Errno"
    rescue Errno::ENETUNREACH
      puts "Enetunreach"
    rescue OpenURI::HTTPError
      puts "Http error"
    rescue Net::HTTPBadResponse
      puts "Http error"
    rescue EOFError
      puts "End of file"
    end
  end
end

def internal_bl_scraper(starting_url)
  begin
      html_file = open(starting_url).read
      html_doc = Nokogiri::HTML(html_file)
      domain = URI.parse(starting_url).host.sub(/^www./,'')
      nodeset = html_doc.xpath('//a')
    rescue
      puts "Issue with origin link #{starting_url}"
    else
      nodeset.map {|element| element["href"]}.compact
      nodeset.each do |link|
        link_anchor = link.text.strip
        if link_anchor.include?('.product-image')
          link_anchor = "Image"
        end
        link = link['href']
        if link.start_with?("http")
          url = URI.parse(link)
          link_domain = url.host.sub(/^www./,'')
          if link_domain == domain
              req = Net::HTTP.new(url.host, url.port)
              if link.start_with?("https")
                req.use_ssl = true
              elsif
                req.use_ssl = false
              end
              req.open_timeout = 10
              req.read_timeout = 10
              res = req.request_head("#{url.path}/")
              res = res.code
            puts "Internal checking #{link} on #{starting_url}, #{res}"
            if res != "200"
              CSV.open(@filepath,'a', @csv_options) do |csv|
                csv << [domain,starting_url,link,link_anchor,res]
              end
            end
          end
        end
      rescue Net::ReadTimeout
        puts "Timeout on #{link}"
      rescue Net::OpenTimeout
        puts "Open Timeout on #{link}"
      rescue OpenSSL::SSL::SSLError
        puts "SSL error on #{link}"
      rescue RuntimeError
        puts "RuntimeError"
      rescue Errno::ECONNRESET
        puts "Erno"
      rescue URI::InvalidURIError
        puts "Invalid error"
      rescue NoMethodError
        puts "No internal link found on #{starting_url}, #{link}"
      rescue SocketError
        puts "Found one on #{starting_url} : #{link}!"
      rescue Errno::ECONNREFUSED
        puts "Errno"
      rescue OpenURI::HTTPError
        puts "Http error"
      end
    end
end

if user_choice == "External"
  CSV.open(@filepath, 'wb', @csv_options) do |csv|
    csv << ['Origin domain','Origin page','Anchor','Link']
  end
  CSV.foreach(source, @csv_options) do |row|
    starting_url = row[0]
    begin
      if starting_url.end_with?('.xml')
        document = Nokogiri::XML(open(starting_url))
        child_sitemaps = document.css('loc').map { |node| node.text }
        child_sitemaps.each do |url|
          external_bl_scraper(url)
        end
      else
        external_bl_scraper(starting_url)
      end
    rescue NoMethodError
      puts "No method on #{starting_url}"
    end
  end
  puts "Crawling over"
else
  CSV.open(@filepath, 'wb', @csv_options) do |csv|
    csv << ['Origin domain','Origin page','Anchor','Link','Status']
  end
  CSV.foreach(source, @csv_options) do |row|
    starting_url = row[0]
    begin
      if starting_url.end_with?('.xml')
        document = Nokogiri::XML(open(starting_url))
        child_sitemaps = document.css('loc').map { |node| node.text }
        child_sitemaps.each do |url|
          internal_bl_scraper(url)
        end
      else
        internal_bl_scraper(starting_url)
      end
    rescue NoMethodError
      puts "No method on #{starting_url}"
    end
  end
end
