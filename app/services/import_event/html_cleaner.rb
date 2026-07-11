require "nokogiri"

module ImportEvent
  class HtmlCleaner
    REMOVE_TAGS = %w[script style noscript iframe svg nav footer header].freeze
    CONTENT_SELECTORS = [
      ".entry-content",
      "article",
      "main",
      "#content",
      ".post-content"
    ].freeze
    MAX_CHARS = 80_000

    def self.clean(html)
      new(html).clean
    end

    def initialize(html)
      @doc = Nokogiri::HTML(html)
    end

    def clean
      REMOVE_TAGS.each { |tag| @doc.css(tag).remove }
      @doc.xpath("//comment()").remove

      text = content_node.inner_html.encode("UTF-8", invalid: :replace, undef: :replace)
      text = text.gsub(/\n{3,}/, "\n\n").strip
      text.length > MAX_CHARS ? text[0, MAX_CHARS] : text
    end

    private

    def content_node
      CONTENT_SELECTORS.each do |selector|
        node = @doc.at_css(selector)
        return node if node
      end

      @doc.at_css("body") || @doc
    end
  end
end
