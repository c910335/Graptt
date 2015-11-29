# Graptt
## Introduction
In order to make browsing PTT ([telnet://ptt.cc](telnet://ptt.cc)) easier with simple HTTP requests,
I made this to convert telnet to APIs by Ruby Grape.
## Installation
First, clone it from github.

   git clone https://github.com/c910335/Graptt.git
   cd Graptt
Second, install the dependencies with bundler.

   bundle install
Third, copy the config file and edit it.

   cp config/settings.sample.rb config/settings.rb
   vim config/settings.rb
Last, rackup!

   rackup
## License
MIT License.
