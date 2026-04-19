# Learn Rails 5.2 Book

Source for the book _Learn Rails 5.2_ by Stefan Wintermeyer.

Content targets Rails 5.2 / Ruby 2.5. The toolchain has been modernized to
Asciidoctor 2.

## Requirements

- Ruby (any modern version; `mise` recommended for management)
- Bundler

## Install

```sh
bundle install
```

## Build

```sh
bundle exec rake html   # HTML output in output/
bundle exec rake pdf    # PDF output in output/
bundle exec rake build  # both
bundle exec rake clean  # remove output/
```

Master file: `learn-rails-52.adoc`.

## License

See individual files for attribution.
