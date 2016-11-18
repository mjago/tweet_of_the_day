require 'oga'
require 'httpclient'
require "htmlentities"
require 'sanitize'

class ReadFeed
  def initialize
    @url = 'http://www.bbc.co.uk/programmes/b01s6xyk/episodes/downloads.rss'.freeze
  end

  def tags
    ['title', 'description', 'link', 'pubDate', 'duration']
  end

  def scrub_desc(desc)
    desc.gsub!("Tweet of the Day is a series of fascinating stories about our British birds inspired by their calls and songs.\n\n",'')
    desc.gsub!('Tweet of the Day is the voice of birds and our relationship with them, from around the world.','')
    desc.strip
  end

  def fetch_rss
    content = HTTPClient.new.get_content(@url)
    File.open('feed', 'w') do |f|
      f.write content
    end
  end

  def read_rss_file
    File.open('feed', 'r') do |f|
      f.read
    end
  end

  def read_rss
    content = read_rss_file
    document = Oga.parse_xml(content)
    parse_doc(document)
  end

  def parse_doc doc
    @rss_articles = []
    urls = []
    doc.xpath('rss/channel/item').each do |x|
      x.xpath('enclosure').each do |y|
        urls << y.get('url')
      end
    end

    doc.xpath('rss/channel/item').each do |item|
      article = parse_tags(item)
      article[:description] = scrub_desc(article[:description])
      article[:url] = urls.shift
      @rss_articles << article
    end
    @rss_articles
  end

  def parse_tags item
    coder = HTMLEntities.new
    article = {}
    tags.each do |name|
      temp = item.at_xpath(name).text
      article[name.to_sym] = Sanitize.clean(coder.decode(temp.force_encoding('utf-8')))
    end
    article
  end
end
