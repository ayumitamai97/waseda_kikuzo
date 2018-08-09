# ruby kikuzo.rb ID PASSWORD YEAR

require "capybara"
require "capybara/dsl"
require "capybara/poltergeist"
require "date"
require "pry"
require "phantomjs"
require "nokogiri"
require "csv"

Capybara.current_driver = :poltergeist

Capybara.configure do |config|
  config.run_server = false
  config.javascript_driver = :poltergeist
  config.app_host = "http://database.asahi.com" # 学内
  config.default_max_wait_time = 120
  config.ignore_hidden_elements = false
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {:timeout=>120, :js=>true, :js_errors=>false,
  :phantomjs => Phantomjs.path,
  :phantomjs_options => ['--ssl-protocol=default', '--ignore-ssl-errors=false']})
end

include Capybara::DSL # 警告が出るが動く

page.driver.headers = { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36" }
page.driver.resize_window(1200, 768)

POSTS_PER_PAGE = 100

def login_inside_univ
  visit "/index.shtml"
  all("#contentMain a")[0].trigger("click")
  sleep(5)
end

def login_outside_univ
  begin
    visit "http://www.wul.waseda.ac.jp.ez.wul.waseda.ac.jp/DOMEST/db_about/dna/dna.html"
    fill_in "user", :with => ARGV[0]
    fill_in "pass", :with => ARGV[1]
    all("input")[3].trigger("click")
    sleep(5)
    visit find("a.A_button")[:href]
  rescue
    retry
  end
  sleep(5)
  all("#contentMain a")[0].trigger("click")
  sleep(20) # ここで読み込みきれないとTypeErrorやUndefined method ... for nilのエラー
end

def search
  # conditions = %w(詳細検索 朝日新聞デジタル アエラ 地域 大阪 名古屋 西部 北海道)
  conditions = %w(詳細検索 朝日新聞デジタル アエラ 地域)
  # 詳細検索以外に関してはselectedの選択肢を外す
  within_frame(all("frame")[1]) do
    conditions.each do |condition|
      find("label", text: condition).trigger("click")
      sleep(1) if condition == "詳細検索"
    end
    all("label", text: "週刊朝日")[1].trigger("click")
    fill_in("txtWord", with: "仮想通貨") # 検索KW
    # all("#optNotNavi6 select")[0].find("option[value='#{ARGV[2]}']").select_option
    # all("#optNotNavi6 select")[1].find("option[value='01']").select_option
    # all("#optNotNavi6 select")[2].find("option[value='01']").select_option
    # all("#optNotNavi6 select")[4].find("option[value='#{ARGV[3]}']").select_option
    # all("#optNotNavi6 select")[5].find("option[value='12']").select_option
    # all("#optNotNavi6 select")[6].find("option[value='31']").select_option
    find("#optNotNavi9 select").find("option[value='#{POSTS_PER_PAGE}']").select_option
    all("input.btext")[0].trigger("click")
    sleep(5)
  end
end

def get_search_result
  CSV.open("csv/crypt_kikuzo.csv", "a") do |csv|
    within_frame(all("frame")[1]) do # frameではなくなった(!?)
      $data = []

      pagenation = all(".fontcolor001")[0].text.to_i / POSTS_PER_PAGE  + 1

      for nth_page in 1..pagenation
        posts_count = all(".fontcolor001")[1].text.split("～")[1].to_i * 2

        for nth_tr in 0..posts_count
          puts nth_tr.to_s + " th tr in " + nth_page.to_s + " th page"
          if nth_tr % 2 == 0
            even_row = nth_tr / 2 + nth_page * ( nth_page - 1 )
          else
            odd_row = 1 + (nth_tr / 2) + nth_page * ( nth_page - 1 )
          end
          # odd_rowはheader of trを入れるところ、even_rowはcontent of trを入れるところ
          
          puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> current $data is:"
          puts $data
          
          $data << []

            if nth_tr == 0
              all("th.topic-list").each { |th| $data[even_row] << th.text }
            elsif nth_tr % 2 == 1 # header of tr
              within(all("table.topic-list tr")[nth_tr]) do
                for nth_td in 0..8
                  if nth_td == 2
                    within(all("td")[nth_td]) do
                      $data[odd_row] << all("nobr")[0].text + all("nobr")[1].text
                    end
                  else
                    $data[odd_row] << all("td")[nth_td].text
                  end
                end
              end
            elsif nth_tr % 2 == 0 && nth_tr != 0 # main content of tr
              within(all("table.topic-list tr")[nth_tr]) do
                $data[even_row] << find("td span a").text
                puts find("td span a").text
                find("td span a").trigger("click")
                sleep 3
                doc = Nokogiri::HTML(page.body)
                $data[even_row] << doc&.css(".detail001")&.inner_text
                go_back
                sleep 3
              end
            end
        end # end of nth_tr
      end
      all("a", text: "次の#{POSTS_PER_PAGE}件")[0].trigger("click")

    end # end if within_frame
    csv_data = CSV.generate() do |data_to_csv|
      $data.each do |d|
        data_to_csv << d
      end
    end
    csv_data.strip!
    csv << [csv_data]
  end
end

login_outside_univ
# login_inside_univ
search
get_search_result
