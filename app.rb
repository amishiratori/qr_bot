require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'dotenv'
require 'line/bot'
require 'rqrcode'
require 'tempfile'


before do
  Dotenv.load
  def client
    @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV['LINE_CHANNEL_SECRET']
        config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    }
  end
  Cloudinary.config do |config|
    config.cloud_name = ENV['CLOUD_NAME']
    config.api_key    = ENV['CLOUDINARY_API_KEY']
    config.api_secret = ENV['CLOUDINARY_API_SECRET']
  end
end

post '/message' do
  body = request.body.read
  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end
  events = client.parse_events_from(body)
  events.each do |event|
      case event
          when Line::Bot::Event::Message
              case event.type
                  when Line::Bot::Event::MessageType::Text
                    content = event.message['text']
                    qrcode = RQRCode::QRCode.new(content)
                    png = qrcode.as_png(
                      resize_gte_to: false,
                      resize_exactly_to: false,
                      fill: 'white',
                      color: 'black',
                      size: 120,
                      border_modules: 4,
                      module_px_size: 6,
                      file: nil # path to write
                    )
                    tmp = Tempfile.new()
                    IO.write(tmp.path, png.to_s)
                    upload = Cloudinary::Uploader.upload(tmp.path)
                    img_url = upload['url']
                    message = {
                      type: 'image',
                      originalContentUrl: img_url,
                      previewImageUrl: imag_url
                    }
                    client.reply_message(event['replyToken'], message)
                  break
                end
              else
                response_message = 'URLを送るとQRコードを返すよ！'
                message = {
                    type: 'text',
                    text: response_message
                  }
                  client.reply_message(event['replyToken'], message)
                break
          end
  end
end
