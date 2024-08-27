require_relative "./env.rb"

# Implicitly needed by ruby-openai gem
require "faraday_middleware"

require "openai"

module OpenAIChat
  CLIENT = OpenAI::Client.new(
    access_token: ENV['OPENAI_ACCESS_TOKEN'],
  )

  COPYRIGHT_QUERY_SYSTEM_PROMPT = <<-END
    Given a copyright string, emit the names of people and/or companies who directly own the copyright.
    Put each on a separate line.
    Do not include parent companies.
    If attributed to open source contributors, include the product name ("X Contributors") if known.
    Do not emit anything else.
  END
    .lines.map(&:strip).join(" ")

  module_function

  def extract_publishers(copyright_string)
    thread = CLIENT.threads.create
    thread_id = thread["id"]

    # https://github.com/alexrudall/ruby-openai/blob/cc01eb502e87bbb8685f692d0165523c8c569871/README.md#chat
    response = CLIENT.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: COPYRIGHT_QUERY_SYSTEM_PROMPT },
          { role: "user", content: copyright_string }
        ],
      }
    )
    response.dig("choices", 0, "message", "content")
      .lines.map(&:strip)
  end
end
