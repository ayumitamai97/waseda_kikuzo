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
  config.default_max_wait_time = 30
  config.ignore_hidden_elements = false
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {:timeout=>120, :js=>true, :js_errors=>false,
  :phantomjs => Phantomjs.path,
  :phantomjs_options => ['--ssl-protocol=default', '--ignore-ssl-errors=false']})
end

include Capybara::DSL # 警告が出るが動く

page.driver.headers = { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/536.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/536.36" }
page.driver.resize_window(1200, 668)

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
    fill_in("yomiuriNewsSearchDto.txtWordSearch", with: "仮想通貨")
    all("label", text: "個別に選択する")[0].trigger("click") # 全国版・地域版
    find("label", text: "全国版").trigger("click") # 全国版・地域版
    find("label", text: "100").trigger("click") # 記事100件取得
    # fill_in("yomiuriNewsSearchDto.txtSYear", with: "#{ARGV[2]}")
    # fill_in("yomiuriNewsSearchDto.txtSMonth", with: "1")
    # fill_in("yomiuriNewsSearchDto.txtSDay", with: "1")
    # fill_in("yomiuriNewsSearchDto.txtEYear", with: "#{ARGV[3]}")
    # fill_in("yomiuriNewsSearchDto.txtEMonth", with: "12")
    # fill_in("yomiuriNewsSearchDto.txtEDay", with: "31")

    find("input.search02").trigger("click")
    sleep(6)
  end
end

def get_trs
  pagenation_count = all(".pageBox a")[-1].text.to_i
  puts ">>>>> Total " + pagenation_count.to_s + " pages"

  for pagenation in 1..pagenation_count  
    puts ">>>>> " + pagenation.to_s + "th page starting"
    posts_num_with_tilde = all(".flR")[0].text.gsub("件", "").split("～")
    posts_num_per_page = posts_num_with_tilde[1].to_i - (posts_num_with_tilde[0].to_i - 2)
    for nth_tr in 0..posts_num_per_page
      begin
        $data << []
        puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> " + nth_tr.to_s + " th tr" + " in " + pagenation.to_s + " th page"
        within(all("tr")[nth_tr]) do
          puts ">>>>>>>> current $data is: "  
          $data << []
          all(".contentsTable th").each do |th|
            $data[nth_tr] << th.text
          end
          td_count = -1
          all(".contentsTable td").each do |td|
            td_count += 1
            $data[nth_tr] << td.text
          end
        end
        if nth_tr >= 2
          begin
            evaluate_script(all(".wp40 a")[nth_tr - 2][:onclick]) # マジックナンバー…
            sleep(2)
            sanit = Sanitize.clean(page.body.scan(%r{<p class="mb10">(.+?)</p>})[0][0])
          rescue
            sanit = "Error Caused in this content"
          end
          puts sanit
          $data[nth_tr] << sanit
          evaluate_script("execute(document.forms['article'], 'yomiuriNewsPageSearchList.action');return false;")
          sleep(3)
        end
      rescue
        retry
        sleep 1
      end
      begin
        if !all("a", text: "次の#{POSTS_PER_PAGE}件")[0].nil? && pagenation == 6
          all("a", text: "次の#{POSTS_PER_PAGE}件")[0].trigger("click")
        elsif pagenation == 6
          all("a", text: "次のページ >")[0]&.trigger("click")
        end
        sleep(3)
      rescue
        break if pagenation == all(".pageBox a")[-1].text.to_i
      end
    end
  end
end

def get_search_result
  CSV.open("csv/crypt_yomidas_new.csv", "a") do |csv|
    within_frame(find("frame")) do
      $data = []
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
