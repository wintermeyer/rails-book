SOURCE  = "learn-ruby-on-rails.adoc"
OUT_DIR = "output"
ASSETS  = "assets"

# Prefer freshly fetched partials (see scripts/fetch-partials.sh);
# fall back to committed copies under assets/ so local builds work
# without network access.
def partial_path(name)
  fresh = File.join(".scratch", "partials", name)
  return fresh if File.exist?(fresh)
  File.join(ASSETS, name)
end

directory OUT_DIR

desc "Fetch fresh nav + footer partials from wincon"
task :fetch_partials do
  sh "./scripts/fetch-partials.sh"
end

desc "Compile the shared chrome.css (Tailwind utilities used by nav + footer)"
task :chrome_css => OUT_DIR do
  # npm ci / npm install must have run before this task. The runner's
  # deploy script handles that; locally, run `npm install` once.
  sh "npx tailwindcss -i assets/chrome.css -o #{OUT_DIR}/chrome.css --minify"
end

desc "Build multi-page HTML (one page per chapter) with the wincon skin"
task :html => [OUT_DIR, :chrome_css] do
  # Use asciidoctor-multipage for one HTML file per top-level chapter.
  # -a linkcss               link to an external stylesheet, don't inline
  # -a stylesheet=book.css,
  # -a stylesdir=.           asciidoctor resolves book.css next to the
  #                          HTML it just wrote (copied in manually below)
  # -a !webfonts             suppress Google Fonts (we ship system fonts)
  # -a !icons                drop the FontAwesome CDN link
  # -a rouge-css=style       inline syntax token styles instead of an
  #                          external rouge-<theme>.css file
  # -a nofooter              suppress the "last updated" boilerplate
  sh %(bundle exec asciidoctor \
    -r asciidoctor-multipage \
    -b multipage_html5 \
    -a linkcss \
    -a copycss! \
    -a stylesheet=book.css \
    -a stylesdir=. \
    -a webfonts! \
    -a !icons \
    -a rouge-css=style \
    -a nofooter \
    -D #{OUT_DIR} #{SOURCE})

  # copycss! disables asciidoctor's own copy step (which errors out
  # because the source lives in assets/, not the repo root). We copy
  # the stylesheet ourselves.
  cp "#{ASSETS}/book.css", "#{OUT_DIR}/book.css"

  # Copy the images directory so <img src="images/..."> resolves.
  mkdir_p "#{OUT_DIR}/images"
  cp_r Dir.glob("images/*"), "#{OUT_DIR}/images/"

  # Wrap every chapter page with the wincon nav and footer, plus a
  # <link> to chrome.css so the Tailwind-utility chrome styles load.
  require_relative "scripts/wrap_pages"
  WrapPages.run(
    html_dir: OUT_DIR,
    nav_path: partial_path("nav.html"),
    footer_path: partial_path("footer.html"),
    extra_stylesheets: ["chrome.css"],
  )
end

desc "Build PDF (single-document, as before)"
task :pdf => OUT_DIR do
  sh "bundle exec asciidoctor-pdf -D #{OUT_DIR} #{SOURCE}"
end

desc "Build HTML and PDF"
task :build => [:html, :pdf]

desc "Remove build artifacts"
task :clean do
  rm_rf OUT_DIR
  rm_rf ".scratch/partials"
end

task :default => :build
