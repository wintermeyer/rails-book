SOURCE  = "learn-rails-52.adoc"
OUT_DIR = "output"

directory OUT_DIR

desc "Build HTML"
task :html => OUT_DIR do
  sh "bundle exec asciidoctor -D #{OUT_DIR} #{SOURCE}"
end

desc "Build PDF"
task :pdf => OUT_DIR do
  sh "bundle exec asciidoctor-pdf -D #{OUT_DIR} #{SOURCE}"
end

desc "Build HTML and PDF"
task :build => [:html, :pdf]

desc "Remove build artifacts"
task :clean do
  rm_rf OUT_DIR
end

task :default => :build
