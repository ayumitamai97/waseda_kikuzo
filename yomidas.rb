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
end

def search
  within_frame(find("frame")) do
    find("#menu03 a").trigger("click")
    fill_in("yomiuriNewsSearchDto.txtWordSearch", with: "訪日 AND 中国人")
    all("label", text: "個別に選択する")[0].trigger("click") # 全国版・地域版
    find("label", text: "全国版").trigger("click") # 全国版・地域版
    fill_in("yomiuriNewsSearchDto.txtSYear", with: "2015")
    fill_in("yomiuriNewsSearchDto.txtSMonth", with: "1")
    fill_in("yomiuriNewsSearchDto.txtSDay", with: "1")
    fill_in("yomiuriNewsSearchDto.txtEYear", with: "2015")
    fill_in("yomiuriNewsSearchDto.txtEMonth", with: "12")
    fill_in("yomiuriNewsSearchDto.txtEDay", with: "31")

    find("input.search02").trigger("click")
    sleep(7)
    save_screenshot "1.png"
  end
end

def get_search_result
  CSV.open("yomidas_data.csv", "w") do |csv|
    within_frame(find("frame")) do
      $data = []
      for nth_tr in 0..51 # なぜか0..50じゃない？
        within(all("tr")[nth_tr]) do
          $data << []
          all(".contentsTable th").each do |th|
            $data[nth_tr] << th.text
          end
          all(".contentsTable td").each do |td|
            $data[nth_tr] << td.text
          end
        end
      end # end of nth_tr
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
