require "capybara"
require "capybara/dsl"
require "capybara/poltergeist"
require "date"
require "pry"
require 'phantomjs'
require 'csv'

Capybara.current_driver = :poltergeist

Capybara.configure do |config|
  config.run_server = false
  config.javascript_driver = :poltergeist
  # config.app_host = "https://dbs.g-search.or.jp" # 学内
  config.app_host = "https://dbs-g-search-or-jp.ez.wul.waseda.ac.jp" # 学外
  config.default_max_wait_time = 30
  config.ignore_hidden_elements = false
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {:timeout=>120, :js=>true, :js_errors=>false,
  :phantomjs => Phantomjs.path,
  :phantomjs_options => ['--ssl-protocol=default', '--ignore-ssl-errors=false']
  # :phantomjs_options => ['--ssl-protocol=any', '--ignore-ssl-errors=true'] # この行は外部WiFi用
  })
end

include Capybara::DSL # 警告が出るが動く

page.driver.headers = { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36" }

def login_inside_univ
  visit "https://mainichi.jp/contents/edu/maisaku/login.html"
  all(".contents_SA a")[0].trigger("click")
  sleep(5)
end

def login_outside_univ
  visit "http://www.wul.waseda.ac.jp.ez.wul.waseda.ac.jp/DOMEST/db_about/maisaku/maisaku.html"
  fill_in "user", :with => ARGV[0]
  fill_in "pass", :with => ARGV[1]
  all("input")[3].trigger("click")
  sleep(5)
  visit find("a.A_button")[:href]
  sleep(5)
  puts "Successfully logged in: current url is " + current_url
end

def search
  visit "/aps/WMSK/main.jsp?uji.verb=GSHWA0300&serviceid=WMSK"
  sleep(15)
  all("tr.middle label")[1].trigger("click") # 東京朝刊
  all("tr.middle label")[6].trigger("click") # 東京夕刊
  all("tr.middle label")[72].trigger("click") # 全て
  fill_in("paraTi", with: "訪日 AND 中国人")
  find("select#paraYearFrom").find("option[value='2015']").select_option
  find("select#paraMonthFrom").find("option[value='1']").select_option
  find("select#paraDayFrom").find("option[value='1']").select_option
  all("select")[4].find("option[value='1']").select_option # 「から」を選択
  find("select#paraYearTo").find("option[value='2015']").select_option
  find("select#paraMonthTo").find("option[value='12']").select_option
  find("select#paraDayTo").find("option[value='31']").select_option
  all("input")[15].trigger("click") # 検索開始
  puts "Starting to search: current url is " + current_url
  sleep(10)
end

def get_search_result
  find(".selectMenu select").find("option[value='200']").select_option
  all(".btnAreaCenter input")[0].trigger("click") # 一覧表示
  sleep(5)
  CSV.open("maisaku_data.csv", "w") do |csv|
    $data = []
    for nth_tr in 0..19 # 検索記事数に合わせて変える
      within(all("table.resultList tr")[nth_tr]) do
        $data << []
        array = all("td")[2].text.split(" ")
        for num in -5..-1
          array.delete_at(num)
        end
        $data[nth_tr] << array.join(" ") # 記事タイトル
        array = all("td")[2].text.split(" ") # 取得し直し
        for num in -5..-1
          $data[nth_tr] << array[num] # タイトル以外
        end
      end
    end # end of nth_tr
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
