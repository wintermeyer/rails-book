# Learn Ruby on Rails

Source for the book _Learn Ruby on Rails_ by Stefan Wintermeyer.

The book targets **Ruby 4.0** and **Ruby on Rails 8.1**. Examples
have been re-run against these versions and screenshots are taken
from fresh Rails 8 scaffolds. Chapters added during the 5.2 → 8.1
refresh include Hotwire (Turbo + Stimulus), the built-in
authentication generator, and the Solid trifecta (Solid Queue /
Solid Cache / Solid Cable).

## Requirements

- Ruby 4.0 (`mise use --global ruby@4.0` recommended)
- Bundler (ships with Ruby 4.0)

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

Master file: `learn-ruby-on-rails.adoc`.

## License

See individual files for attribution.
