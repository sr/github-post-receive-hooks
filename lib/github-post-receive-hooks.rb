require 'net/http'
require 'net/https'
require 'nokogiri'

class PostreceiveHooks
  def self.run(user, token, repo, enabled_urls, disabled_urls)
    new(user, token, repo, enabled_urls, disabled_urls).run
  end

  def initialize(user, token, repo, enabled_urls, disabled_urls)
    @user          = user
    @token         = token
    @repo          = repo
    @enabled_urls  = enabled_urls
    @disabled_urls = disabled_urls
  end

  def run
    raise "No user specified" if @user.nil? || @user.empty?
    raise "No token specified" if @token.nil? || @token.empty?
    raise "No repo specified" if @repo.nil? || @repo.empty?

    puts "Current: "
    puts current_urls

    puts "Required: "
    puts required_urls

    update

    puts "Confirmed: "
    puts current_urls
  end

  def current_urls
    @current_urls ||= load_current_urls
  end

  def load_current_urls
    req = Net::HTTP::Get.new(uri.path)
    req.set_form_data(auth, '&')

    res = fetch(req)

    raise "Repo not found" unless res.code == "200"

    doc = Nokogiri::HTML(res.body)
    form = doc.at("form[action='/#{@repo}/edit/postreceive_urls']")
    form.search("input[name='urls[]']").map {|x| x["value"]}.compact
  end

  def required_urls
    (current_urls + @enabled_urls - @disabled_urls).uniq
  end

  def update
    uri = URI.parse "#{admin_page}/postreceive_urls"
    req = Net::HTTP::Post.new(uri.path)

    req.set_form_data(auth + required_urls_data, '&')

    res = fetch(req)
    unless res["Location"] == "#{admin_page}?hooks=1"
      raise "Could not update urls"
    end

    @current_urls = nil
  end

  def required_urls_data
    required_urls.map do |url|
      ["urls[]", url]
    end
  end

  def uri
    @uri ||= URI.parse(admin_page)
  end

  def admin_page
    "https://github.com/#{@repo}/edit"
  end

  def fetch(req)
    server = Net::HTTP.new uri.host, uri.port
    server.use_ssl = uri.scheme == 'https'
    server.verify_mode = OpenSSL::SSL::VERIFY_NONE
    server.start {|http| http.request(req) }
  end

  def auth
    [[:login, @user], [:token, @token]]
  end
end
