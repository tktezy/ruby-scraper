# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'csv'
Bundler.require(:default)

class PageParser
  def initialize(url, file_name)
    @web_page = url
    @file_name = file_name
    @all_products_urls = []
    @result = []
  end

  def parse
    puts 'Parsing started:'
    product_urls(find_all_category_pages)
    puts "Found #{@all_products_urls.length} product pages"
    parse_products(@all_products_urls)
    write_to_csv(@result)
    puts 'Parsing successfully ended'
  end

  private

  # find all products URLs and save them in the array @all_products_urls
  def product_urls(pagination_urls)
    puts 'Finding products URLs'
    pagination_urls.each do |html|
      curl_page = Curl.get(html)
      parsed_page = Nokogiri::HTML(curl_page.body_str)
      parsed_page.xpath("//*[@id='product_list']/li[*]").each do |node|
        sections_html = Nokogiri::HTML(node.inner_html)
        html_a_tags = sections_html.xpath('//*/div[1]/div[2]/div[2]/div[1]/h2/a')
        product_link = html_a_tags.attribute('href').value
        puts "Product found - #{product_link}"
        @all_products_urls << product_link
      end
    end
    puts 'Done'
  end

  # find the URLs of all pagination pages
  def find_all_category_pages
    puts 'Finding pagination pages'
    pagination_urls = []
    i = 2
    pagination_urls << @web_page
    page_url = @web_page + "?p=#{i}"

    while Curl.get(page_url).response_code == 200
      pagination_urls << page_url
      puts "Found #{i} category page"
      i += 1
      page_url = @web_page + "?p=#{i}"
    end

    puts 'Done'
    pagination_urls
  end

  # Parsing all founded products and call method, that parse product variations
  def parse_products(urls)
    puts 'Products pages parsing started:'
    urls.each do |url|
      puts "Parsing #{url}"
      product_curl = Curl.get(url)
      parsed_product = Nokogiri::HTML(product_curl.body_str)
      parse_multiproducts(parsed_product)
    end
    puts 'Products pages parsing successfully ended'
  end

  # Parsing product variations and save [full_title, image, price] in the array @result
  def parse_multiproducts(parsed_product)
    puts 'Parsing product variations'
    product_title = find_title(parsed_product)
    image = find_image(parsed_product)

    fieldsets = parsed_product.xpath("//*[@id='attributes']/fieldset[*]")

    fieldsets.each do |fieldset|
      product_group = Nokogiri::HTML(fieldset.inner_html)
      packing_type = product_group.text.match(/(?<pack>\w+)/)[:pack]

      product_group.xpath('//*/div/ul/li[*]').each do |node|
        packing_type = node.to_html.match(%r{(?<=important">).*?(?=</span>)})
        full_title = product_title + " - #{packing_type}"
        price = find_price(node).to_s
        @result << [full_title, image, price]
      end
    end
    puts 'Done'
  end

  def find_title(parsed_product)
    parsed_product.xpath('//*/div/div[2]/div[2]/div[1]/div[2]/h1').text
  end

  def find_image(parsed_product)
    parsed_product.xpath("//*[@id='bigpic']").attribute('src').value
  end

  def find_price(parsed_product)
    parsed_product.to_html.match(%r{(?<=price_comb">).*?(?=</span>)})
  end

  def write_to_csv(result)
    puts 'Writing in CSV'
    CSV.open(@file_name, 'wb') do |csv|
      csv << %w[Title Img Price]
      result.each do |found_item|
        csv << found_item
      end
    end
    puts 'Done'
  end
end

parser = PageParser.new(ARGV[0], ARGV[1])
parser.parse
