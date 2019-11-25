
require 'curb'
require 'nokogiri'
require 'csv'

class Parser
  PRODUCTS_COUNT = '//span[@class="heading-counter"]'
  PRODUCTS_URL = '//a[@class="product_img_link product-list-category-img"]/@href'
  PRODUCT_IMAGE = '//img[@id="bigpic"]/@src'
  PRODUCT_PRICE = './/span[@class="price_comb"]'
  PRODUCT_SOLO_PRICE = '//span[@id="our_price_display"]'
  PRODUCT_WEIGHT = './/span[@class="radio_label"]'
  PRODUCT_TITLE = '//h1[@class="product_main_name"]'
  PRODUCT_ATTRIBUTES_TABLE = '//div[@id="attributes"]//ul'
  PRODUCT_ATTRIBUTES_VARIATIONS = '//div[@id="attributes"]//ul/li'

  def initialize(url, file_name)
    @url = url
    @file_name = file_name
    @pages_count = page_counter
    @products = []
    collect_products
  end

  def get_html_and_use_xpath(url, xpath)
    http = Curl.get(url)
    html = Nokogiri::HTML(http.body_str)
    html.xpath(xpath)
  end

  def get_nokogoiri_doc(url)
    http = Curl.get(url)
    html = Nokogiri::HTML(http.body_str)
  end

  def page_counter
    per_page_url = get_html_and_use_xpath(@url, PRODUCTS_URL)
    per_page = per_page_url.count
    total = get_html_and_use_xpath(@url, PRODUCTS_COUNT).text.to_i
    last_page = (total.to_f / per_page.to_f).ceil

    last_page.to_i
  end

  def products_links
    puts 'COLLECTING LINKS'

    links = []
    category_urls.each do |link|
      category_page = get_nokogoiri_doc(link)
      category_page.xpath(PRODUCTS_URL).each do |product_url|
        links << product_url.text
      end
    end
    links
  end

  def category_urls
    puts 'COLLECTING PRODUCTS INFORMATION'

    urls = []
    page = 1
    while page <= @pages_count
      url = @url + "?p=#{page}"
      url = @url if page == 1

      urls << url
      page += 1
    end

    urls
  end

  def parse_solo_product(doc)
    @products << {
      title: doc.xpath(PRODUCT_TITLE).text.strip,
      price: doc.xpath(PRODUCT_SOLO_PRICE).text.gsub(%r{€/u|€}, '').strip,
      image: doc.xpath(PRODUCT_IMAGE).text
    }
  end

  def parse_multi_product(doc)
    title = doc.xpath(PRODUCT_TITLE).text.strip
    image = doc.xpath(PRODUCT_IMAGE).text
    doc.xpath(PRODUCT_ATTRIBUTES_VARIATIONS).each do |attributes|
      weight = attributes.xpath(PRODUCT_WEIGHT).text.strip
      @products << {
        title: title + ' - ' + weight,
        price: attributes.xpath(PRODUCT_PRICE).text.gsub(%r{€/u|€}, '').strip,
        image: image
      }
    end
  end

  def collect_products
    puts 'COLLECTING CATEGORY URLS'

    products_links.each do |product_url|
      product_doc = get_nokogoiri_doc(product_url)

      if product_doc.xpath(PRODUCT_ATTRIBUTES_TABLE).empty?
        parse_solo_product(product_doc)
      else
        parse_multi_product(product_doc)
      end
    end
  end

  def csv_file
    puts 'WRITING RESULTS TO THE FILE'
    CSV.open("#{@file_name}.csv", 'wb') do |csv|
      csv << %w[Name Price Image]
      @products.each do |product|
        csv << [product[:title], product[:price], product[:image]]
      end
      puts 'THE RESULTS ARE SUCCESSFULLY RECORDED'
    end
  end
end

if ARGV[0] && ARGV[1]
  parser = Parser.new(ARGV[0], ARGV[1])
  parser.csv_file
else
  puts 'Error! The request requires two arguments: url and file name.'
  return
end
