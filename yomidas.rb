require "capybara"
require "capybara/dsl"
require "capybara/poltergeist"
require "date"
require "pry"
require "phantomjs"
require "nokogiri"
require "csv"
require "sanitize"

Capybara.current_driver = :poltergeist

Capybara.configure do |config|
  config.run_server = false
  config.javascript_driver = :poltergeist
  config.app_host = "https://database.yomiuri.co.jp" # 学内
  # config.app_host = "https://database.yomiuri.co.jp.ez.wul.waseda.ac.jp" # 学外ではapp_hostを使わない
  config.default_max_wait_time = 30
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

def login_inside_univ
  visit "/rekishikan/"
  sleep(5)
end

def login_outside_univ
  visit "http://www.wul.waseda.ac.jp.ez.wul.waseda.ac.jp/DOMEST/db_about/yomiuri/yomidas.html"
  fill_in "user", :with => ARGV[0]
  fill_in "pass", :with => ARGV[1]
  all("input")[3].trigger("click")
  sleep(5)
  visit find("a.A_button")[:href]
  sleep(5)
  puts "Current URL is " + current_url
end

def search
  sleep(5)
  within_frame(find("frame")) do
    find("#menu03 a").trigger("click")
    fill_in("yomiuriNewsSearchDto.txtWordSearch", with: "訪日 AND 中国人 AND 爆買い")
    all("label", text: "個別に選択する")[0].trigger("click") # 全国版・地域版
    find("label", text: "全国版").trigger("click") # 全国版・地域版
    find("label", text: "100").trigger("click") # 記事100件取得
    fill_in("yomiuriNewsSearchDto.txtSYear", with: "#{ARGV[2]}")
    fill_in("yomiuriNewsSearchDto.txtSMonth", with: "1")
    fill_in("yomiuriNewsSearchDto.txtSDay", with: "1")
    fill_in("yomiuriNewsSearchDto.txtEYear", with: "#{ARGV[3]}")
    fill_in("yomiuriNewsSearchDto.txtEMonth", with: "12")
    fill_in("yomiuriNewsSearchDto.txtEDay", with: "31")

    find("input.search02").trigger("click")
    sleep(7)
  end
end

def get_trs
  posts_num = all(".flR")[0].text.gsub("件", "").split("～")
  page_posts_num = posts_num[1].to_i - (posts_num[0].to_i - 2)
  for nth_tr in 0..page_posts_num # なぜか0..100じゃない？
    within(all("tr")[nth_tr]) do
      $data << []
      all(".contentsTable th").each do |th|
        $data[nth_tr] << th.text
      end
      td_count = -1
      all(".contentsTable td").each do |td|
        td_count += 1
        $data[nth_tr] << td.text
      end
      # binding.pry
      if nth_tr >= 1
        find(".wp40 a").trigger("click")
        sleep(3)
        binding.pry
        puts Sanitize.clean(page.body.scan(%r{<p class="mb10">(.+?)</p>})[0][0])
        $data[nth_tr] << Sanitize.clean(page.body.scan(%r{<p class="mb10">(.+?)</p>})[0][0]) || 0
        evaluate_script("execute(document.forms['article'], 'yomiuriNewsPageSearchList.action');return false;")
      end
      sleep(3)
    end
  end
end

def get_search_result
  CSV.open("csv/yomidas_data_#{ARGV[2]}to#{ARGV[3]}.csv", "w") do |csv|
    within_frame(find("frame")) do
      $data = []
      get_trs
      evaluate_script(
        "pageSortSubmit('yomiuriNewsPageSearchList.action',
         'search', 100, '0', 'DESC', 'PBLSDT');return false;") # 2ページ目用
      sleep(5)
      get_trs
    end # end if within_frame
    csv_data = CSV.generate() do |csv|
      $data.each do |d|
        csv << d
      end
    end
    csv_data.gsub!('"', '') # とりあえず
    csv << [csv_data]
  end
end

login_outside_univ
# login_inside_univ
search
get_search_result
