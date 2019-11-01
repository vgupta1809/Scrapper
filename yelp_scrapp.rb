require 'headless'
require 'watir'
require 'cgi'
require 'csv'
require 'pry'
#https://www.yelp.com/search?find_desc=auto%20repair&find_loc=Detroit%2C%20MI&start=10
def perform(w, url)
  w.goto(url)
  @name = ""
  @no_of_reviews = ""  
  @rating = ""
  @phone = ""
  @address = ""
  @city = ""
  @state = ""
  @zipcode = ""
  @neighborhood = ""
  #
  @name = (w.elements(css: 'div.main-content-wrap.main-content-wrap--full > div > div.lemon--div__373c0__1mboc.spinner-container__373c0__N6Hff.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-t3.u-space-b6.border-color--default__373c0__2oFDT > div > div > div.lemon--div__373c0__1mboc.stickySidebar--heightContext__373c0__133M8.tableLayoutFixed__373c0__12cEm.arrange__373c0__UHqhV.u-space-b6.u-padding-b4.border--bottom__373c0__uPbXS.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-grid-column--8__373c0__2yTAx.u-padding-r6.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-b3.border-color--default__373c0__2oFDT > div > div:nth-child(1) > h1').map(&:text).join(' ') rescue '')
  if @name.empty?
    @name = (w.elements(css:'h1.lemon--h1__373c0__2ZHSL').map(&:text).join(' ') )
  end
  #
  @no_of_reviews = w.elements(css: 'div.biz-rating')[0].text rescue ''
  @no_of_reviews = w.elements(css: 'div.main-content-wrap.main-content-wrap--full > div > div.lemon--div__373c0__1mboc.spinner-container__373c0__N6Hff.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-t3.u-space-b6.border-color--default__373c0__2oFDT > div > div > div.lemon--div__373c0__1mboc.stickySidebar--heightContext__373c0__133M8.tableLayoutFixed__373c0__12cEm.arrange__373c0__UHqhV.u-space-b6.u-padding-b4.border--bottom__373c0__uPbXS.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-grid-column--8__373c0__2yTAx.u-padding-r6.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-b3.border-color--default__373c0__2oFDT > div > div.lemon--div__373c0__1mboc.arrange__373c0__UHqhV.gutter-6__373c0__zqA5A.vertical-align-middle__373c0__2TQsQ.u-space-b1.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-fill__373c0__17z0h.border-color--default__373c0__2oFDT > p')[0].text if @no_of_reviews.empty? rescue ''
  @no_of_reviews = @no_of_reviews.split(' ').first if @no_of_reviews
  @website = nil
  #
  @rating = (w.elements(css: 'div.biz-rating')[0].divs(class: 'i-stars')[0].title.split(' ').first rescue '')
  @rating = w.elements(css: "div.main-content-wrap.main-content-wrap--full > div > div.lemon--div__373c0__1mboc.spinner-container__373c0__N6Hff.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-t3.u-space-b6.border-color--default__373c0__2oFDT > div > div > div.lemon--div__373c0__1mboc.stickySidebar--heightContext__373c0__133M8.tableLayoutFixed__373c0__12cEm.arrange__373c0__UHqhV.u-space-b6.u-padding-b4.border--bottom__373c0__uPbXS.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-grid-column--8__373c0__2yTAx.u-padding-r6.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-b3.border-color--default__373c0__2oFDT > div > div.lemon--div__373c0__1mboc.arrange__373c0__UHqhV.gutter-6__373c0__zqA5A.vertical-align-middle__373c0__2TQsQ.u-space-b1.border-color--default__373c0__2oFDT > div:nth-child(1) > span > div")[0].attributes[:aria_label].split(' ').first if @rating.empty? rescue ''
  #
  @phone = (w.elements(css: 'span.biz-phone')[0].text rescue '')
  if @phone.empty?
    @phone = (w.elements(css: 'div.main-content-wrap.main-content-wrap--full > div > div.lemon--div__373c0__1mboc.spinner-container__373c0__N6Hff.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-t3.u-space-b6.border-color--default__373c0__2oFDT > div > div > div.lemon--div__373c0__1mboc.stickySidebar--heightContext__373c0__133M8.tableLayoutFixed__373c0__12cEm.arrange__373c0__UHqhV.u-space-b6.u-padding-b4.border--bottom__373c0__uPbXS.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.stickySidebar--fullHeight__373c0__1szWY.arrange-unit__373c0__1piwO.arrange-unit-grid-column--4__373c0__3oeu6.border-color--default__373c0__2oFDT > div > div > section > div > div > div > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-fill__373c0__17z0h.border-color--default__373c0__2oFDT > p:nth-child(2)').map(&:text).join(' ') rescue '')
    @phone = @phone.split('(').last.insert(0, '(') unless @phone.nil? rescue ''
  end
  #
  href = w.elements(css: 'span.biz-website')[0].links.first.href rescue nil
  href = w.links(css: 'div.main-content-wrap.main-content-wrap--full > div > div.lemon--div__373c0__1mboc.spinner-container__373c0__N6Hff.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-t3.u-space-b6.border-color--default__373c0__2oFDT > div > div > div.lemon--div__373c0__1mboc.stickySidebar--heightContext__373c0__133M8.tableLayoutFixed__373c0__12cEm.arrange__373c0__UHqhV.u-space-b6.u-padding-b4.border--bottom__373c0__uPbXS.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.stickySidebar--fullHeight__373c0__1szWY.arrange-unit__373c0__1piwO.arrange-unit-grid-column--4__373c0__3oeu6.border-color--default__373c0__2oFDT > div > div > section > div > div > div > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-fill__373c0__17z0h.border-color--default__373c0__2oFDT > a') rescue nil
  if href.count > 1
    href = href.first.href
  else
    href = nil
  end
  
  ## 
   if href
    uri = URI.parse(href)
    @website = CGI.parse(uri.query)['url']&.first
   end
  @full_address = ( w.elements(css: 'div.map-box-address').map(&:text).join(' ') rescue '')
  @full_address = ( w.elements(css: 'li.biz-contact-info_directions')[0].addresses.map(&:text).join(' ') rescue '') if @full_address.empty? 
  #
  @full_address = (w.elements(css: 'div.main-content-wrap.main-content-wrap--full > div > div.lemon--div__373c0__1mboc.spinner-container__373c0__N6Hff.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.u-space-t3.u-space-b6.border-color--default__373c0__2oFDT > div > div > div.lemon--div__373c0__1mboc.stickySidebar--heightContext__373c0__133M8.tableLayoutFixed__373c0__12cEm.arrange__373c0__UHqhV.u-space-b6.u-padding-b4.border--bottom__373c0__uPbXS.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.stickySidebar--fullHeight__373c0__1szWY.arrange-unit__373c0__1piwO.arrange-unit-grid-column--4__373c0__3oeu6.border-color--default__373c0__2oFDT > div > div > section > div > div > div > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-fill__373c0__17z0h.border-color--default__373c0__2oFDT > address > p > span').first.text rescue '')
  #
  @address, @state_zip_neighborhood = @full_address.split(',')
  @address = @address.to_s.split("\n")
  @city = @address.pop if @address.count > 1
  @address = @address.join(' ')
  @state_zipcode, @neighborhood = @state_zip_neighborhood.to_s.split("\n").map(&:strip)
  @state, @zipcode = @state_zipcode.to_s.split(' ')
  #
  @csv_data = [@name, @phone, @address, @city, @state, @zipcode, @neighborhood, @website, @no_of_reviews, @rating, url]
  File.open("yelp_meallen.csv", "a") do |f|
    f.write(@csv_data.to_csv)
  end
  rescue Exception => e
    puts e.inspect
    puts url
    File.open("yelp_mcallen_error.csv", "a") do |f|
      f.write("#{url}\n")
    end
    sleep(4)
end


#headless = Headless.new
#headless.start

@w = Watir::Browser.new :chrome , headless: true

@yelp_shop_urls = []
(0..22).each do |n|
  @start = n * 10
  url = "https://www.yelp.com/search?find_desc=auto%20repair&find_loc=McAllen%2C%20TX&start=#{@start}"

  @w.goto(url)
  #
  #elements = @w.elements(css: 'lemon--div__373c0__1mboc businessNameWithNoVerifiedBadge__373c0__24q4s display--inline-block__373c0__2de_K border-color--default__373c0__2oFDT > h3')
  elements = @w.links(css: 'div:nth-child(4) > div.lemon--div__373c0__1mboc.spinner-container__373c0__N6Hff.border-color--default__373c0__2oFDT.background-color--white__373c0__GVEnp > div.lemon--div__373c0__1mboc.container__373c0__13FCe.space3__373c0__DeVwY > div > div.lemon--div__373c0__1mboc.mainContentContainer__373c0__32Mqa.arrange__373c0__UHqhV.gutter-30__373c0__2PiuS.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.mapColumnTransition__373c0__10KHB.arrange-unit__373c0__1piwO.arrange-unit-fill__373c0__17z0h.border-color--default__373c0__2oFDT > div > ul > li > div > div > div.lemon--div__373c0__1mboc.arrange__373c0__UHqhV.border-color--default__373c0__2oFDT > div.lemon--div__373c0__1mboc.arrange-unit__373c0__1piwO.arrange-unit-fill__373c0__17z0h.border-color--default__373c0__2oFDT > div > div > div.lemon--div__373c0__1mboc.mainAttributes__373c0__1r0QA.arrange-unit__373c0__1piwO.arrange-unit-fill__373c0__17z0h.border-color--default__373c0__2oFDT > div > div:nth-child(1) > div > div > h3 > p > a')
  elements.each do |elem|
    href = elem.href
    uri = URI.parse(href)
    redirect_url = CGI.parse(uri.query)['redirect_url'].first
    url = (redirect_url || href)
    @yelp_shop_urls << url
  end
end

@yelp_shop_urls.uniq.compact.each do |url|
  perform(@w, url)
end
