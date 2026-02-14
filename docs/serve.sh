#!/bin/bash
# Start Jekyll development server

# Initialize rbenv
eval "$(rbenv init - bash)"

# Start Jekyll with live reload
bundle exec jekyll serve --livereload
