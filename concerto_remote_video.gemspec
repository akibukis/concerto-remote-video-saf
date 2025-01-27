$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'concerto_remote_video_saf/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'concerto_remote_video_saf'
  s.version     = ConcertoRemoteVideo::VERSION
  s.authors     = ['Brian Michalski']
  s.email       = ['bmichalski@gmail.com']
  s.homepage    = 'https://github.com/akibukis/concerto-remote-video-saf'
  s.summary     = 'Remotely hosted video for Concerto 2 (mod for custom Concerto deployment)'
  s.description = 'Adds support for remotely hosted videos, like YouTube or vimeo, in Concerto 2'
  s.license     = 'Apache 2.0'

  s.files = Dir['{app,config,db,lib,public}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'rails'
  s.add_dependency 'video_info', '<2.6' # 2.6 and up require ruby 2.2 which jessie does not have
end
