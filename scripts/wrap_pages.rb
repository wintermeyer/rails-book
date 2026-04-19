# Post-processes asciidoctor-multipage output so every chapter page:
#
#  * carries the wincon site nav at the top of <body>
#  * carries the wincon site footer at the bottom of <body>
#  * gets a per-chapter <title>, not the book title repeated
#  * drops the FontAwesome CDN, rouge-*.css and the inline default
#    style block (our book.css already covers everything)

require "cgi"

module WrapPages
  module_function

  def run(html_dir:, nav_path:, footer_path:, extra_stylesheets: [])
    nav = File.read(nav_path)
    footer = File.read(footer_path)

    Dir.glob(File.join(html_dir, "*.html")).each do |file|
      html = File.read(file)
      html = strip_noise(html)
      html = inject_stylesheets(html, hrefs: extra_stylesheets)
      html = inject_chrome(html, nav: nav, footer: footer)
      html = set_title(html, file: file)
      File.write(file, html)
    end
  end

  # Add <link rel="stylesheet"> tags just before </head>. Used to
  # load chrome.css alongside the book.css that asciidoctor emits.
  def inject_stylesheets(html, hrefs:)
    return html if hrefs.empty?

    tags = hrefs.map { |h| %(<link rel="stylesheet" href="#{h}">) }.join("\n")
    html.sub(%r{</head>}, "#{tags}\n</head>")
  end

  # Drop links and styles that fight with book.css.
  def strip_noise(html)
    # FontAwesome CDN (only present if someone forgot -a !icons).
    html = html.gsub(
      %r{<link[^>]*font-awesome[^>]*>\s*}i, ""
    )
    # Auxiliary rouge-<theme>.css that asciidoctor generates when
    # rouge-css=class. When rouge-css=style is in effect this link
    # is not emitted, but we strip it defensively.
    html = html.gsub(
      %r{<link[^>]*rouge-[^"']+\.css[^>]*>\s*}i, ""
    )
    # The inline <style> block that asciidoctor-multipage writes
    # for its own TOC and nav-footer quirks. We re-implement those
    # rules in book.css.
    html = html.sub(
      %r{<style>\s*\.toc-current.*?</style>\s*}m, ""
    )
    html
  end

  def inject_chrome(html, nav:, footer:)
    html = html.sub(/<body([^>]*)>/) do
      "<body#{Regexp.last_match(1)}>\n#{nav}\n"
    end
    html.sub(%r{</body>}, "#{footer}\n</body>")
  end

  # Chapter heading is the first <h1> inside #content. The landing
  # page (learn-ruby-on-rails.html) stays as "Learn Ruby on Rails".
  def set_title(html, file:)
    filename = File.basename(file, ".html")
    return html if filename == "learn-ruby-on-rails"

    # Scope: first h1 or h2 after `id="content"`. Chapter pages
    # emit the heading as <h2>, the landing page uses <h1>.
    chapter_title = html[
      %r{id="content".*?<h[12][^>]*>([^<]+)</h[12]>}m,
      1,
    ]
    return html unless chapter_title

    chapter_title = CGI.unescapeHTML(chapter_title).strip
    new_title = "#{chapter_title} · Learn Ruby on Rails"

    html.sub(
      %r{<title>[^<]*</title>},
      "<title>#{CGI.escapeHTML(new_title)}</title>",
    )
  end
end
