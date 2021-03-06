require "json"
require "net/http"

class SubmissionWorker
  include Sidekiq::Worker

  def perform(params, remote_ip)
    if pass_recaptcha?(params["g-recaptcha-response"], remote_ip) == false
      puts "Recaptcha failed! #{params["g-recaptcha-response"]}, #{remote_ip}"
      return false
    end

    body = app_body(params)

    Mail.deliver do
      to params["email"]
      from ENV["FROM_EMAIL"]
      subject "Engineering Application Recieved"
      html_part do
        content_type 'text/html; charset=UTF-8'
        body "Hi there,<br>We've recieved your application. We'll be in touch soon!<br/><hr width='100%' size='2' color='#ddd'>#{body}"
      end
    end

    Mail.deliver do
      from params["email"]
      to ENV["TO_EMAIL"]
      subject "Engineering Application Recieved"
      html_part do
        content_type 'text/html; charset=UTF-8'
        body "We've recieved an application.<br/><hr width='100%' size='2' color='#ddd'>#{body}"
      end
    end
  end

  def pass_recaptcha?(response, ip)
    res = Net::HTTP.post_form(
      URI.parse("https://www.google.com/recaptcha/api/siteverify"),
      {
        secret: ENV["RECAPTCHA_KEY"],
        remoteip: ip,
        response: response
      }
    )

    JSON.parse(res.body)["success"] == true
  end

  def app_body(params)
    "<strong>Name:</strong> #{params["name"]}<br/>
    <strong>Email:</strong> #{params["email"]}<br/>
    <strong>Github Profile URL:</strong> #{params["github_profile_url"]}
    <br/><strong>Why work with us?: </strong> #{format_cover(params["cover_letter"])}"
  end

  private
    def format_cover(text)
      return text if text.nil?
      text.gsub("\n", "<br />")
    end

end