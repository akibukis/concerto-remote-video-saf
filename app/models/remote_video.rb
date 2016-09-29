class RemoteVideo < Content
  after_initialize :set_kind, :create_config#, :load_info

  after_find :load_config

  before_validation :load_info
  before_validation :save_config

  validate :video_id_must_exist
  #todo: put back, commented out because I keep getting duration is not a number
  #validates :duration, :numericality => { :greater_than => 0 }
  validate :video_vendor_supported

  DISPLAY_NAME = 'Video'
  VIDEO_VENDORS = {
    :HTTPVideo => { :id => "HTTPVideo", :name => "Self-hosted Video", :url => ""},
    :YouTube => { :id => "YouTube", :name => "YouTube", :url => "https://www.youtube.com/embed/" },
    :Vimeo => { :id => "Vimeo", :name => "Vimeo", :url => "https://player.vimeo.com/video/" },
    :Wistia => { :id => "Wistia", :name => "Wistia", :url => "https://fast.wistia.net/embed/iframe/" },
    :DailyMotion => { :id => "DailyMotion", :name => "DailyMotion", :url => "https://www.dailymotion.com/embed/video/" }
  }

  attr_accessor :config

  # Automatically set the kind for the content
  # if it is new.  We use this hidden type that no fields
  # render so Dynamic Content meta content never gets displayed.
  def set_kind
    return unless new_record?
    self.kind = Kind.where(:name => 'Graphics').first
  end

  # Create a new configuration hash if one does not already exist.
  # Called during `after_initialize`, where a config may or may not exist.
  def create_config
    self.config = {} if !self.config
  end

  # Load a configuration hash.
  # Converts the JSON data stored for the content into the configuration.
  # Called during `after_find`.
  def load_config
    self.config = JSON.load(self.data)
  end

  # Prepare the configuration to be saved.
  # Compress the config hash back into JSON to be stored in the database.
  # Called during `before_valication`.
  def save_config
    self.data = JSON.dump(self.config)
  end

  def self.form_attributes
    attributes = super()
    # what about  :thumb_url, :title, :description
    attributes.concat([:config => [:video_vendor, :video_id, :allow_flash]])
  end

  # Load some info about this video from YouTube.
  def load_info
    require 'video_info'

    # dont abort if there is a duration specified
    return if self.config['video_id'].nil? #|| !self.duration.nil?
    return if !self.new_record?
    if self.config['video_vendor'] == VIDEO_VENDORS[:YouTube][:id]
      video = VideoInfo.new("http://www.youtube.com/watch?v=#{URI.escape(self.config['video_id'])}")
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:Vimeo][:id]
      video = VideoInfo.new("http://vimeo.com/#{URI.escape(self.config['video_id'])}")
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:Wistia][:id]
      video = VideoInfo.new("http://fast.wistia.com/embed/medias/#{URI.escape(self.config['video_id'])}")
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:DailyMotion][:id]
      video = VideoInfo.new("http://dailymotion.com/video/#{URI.escape(self.config['video_id'])}")
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:HTTPVideo][:id]
      # self hosted video, skip video info gem configuration below 
      self.config['preview_code'] = "<video preload controls width=\"100%\"><source src=\"#{self.config['video_id']}\" /></video>"
      self.config['video_available'] = true
      return
    end

    # Video info gem details
    if !video.nil? and video.available?
      # some vimeo videos have zero for their duration, so in that case use what the user supplied
      self.duration = (video.duration.to_i > 0 ? video.duration.to_i : self.duration.to_i)
      self.config['title'] = video.title
      self.config['description'] = video.description
      self.config['video_id'] = video.video_id
      self.config['duration'] = video.duration
      self.config['preview_url'] = video.embed_url
      self.config['preview_code'] = video.embed_code
      # set video thumbnail using video info or using YouTube image url to bypass API restrictions
      if video.provider == VIDEO_VENDORS[:YouTube][:id]
        self.config['thumb_url'] = "https://i.ytimg.com/vi/" + video.video_id + "/hqdefault.jpg"
      else
        self.config['thumb_url'] = video.thumbnail_large
      end
    end
    # Store video availablility to skip preview rendering
    self.config['video_available'] = video.available?
  end

  def self.preview(data)
    require 'video_info'

    begin
      o = RemoteVideo.new()
      o.config['video_id'] = data[:video_id]
      o.config['video_vendor'] = data[:video_vendor]
      o.load_info

    rescue => e
      return "Unable to preview.  #{e.message}"
    end

    return o.config
  end

  def preview
    begin
      results = render_preview
    rescue => e
      results = "Unable to preview.  #{e.message}"
    end

    return results
  end

  # Build a URL for an iframe player.
  def player_url(params={})
    url = VIDEO_VENDORS[self.config['video_vendor'].to_sym][:url] + self.config['video_id']
    if self.config['allow_flash'] == '0'
      params['html5'] = 1
    end
    url += '?' + URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))
    return url
  end

  def video_id_must_exist
    if config['video_id'].empty?
      errors.add(:video_id, 'could not be found')
    end
  end

  def video_vendor_supported
    if config['video_vendor'].empty? || !VIDEO_VENDORS.collect { |a,b| b[:id] }.include?(config['video_vendor'])
      errors.add(:video_vendor, 'must be ' + VIDEO_VENDORS.collect { |a,b| b[:id] }.join(" or "))
    end
  end

  def render_details
    if self.config['video_vendor'] == VIDEO_VENDORS[:YouTube][:id]
      settings = {
        :autoplay => 1,         # Autostart the video
        :end => self.duration,  # Stop it around the duration
        :controls => 0,         # Don't show any controls
        :modestbranding => 1,   # Use the less fancy branding
        :rel => 0,              # Don't show related videos
        :showinfo => 0,         # Don't show the video info
        :iv_load_policy => 3    # Don't show any of those in-video labels
      }
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:Vimeo][:id]
      settings = {
        :api => 1,                # use Javascript API
        :player_id => 'playerv',  #arbitrary id of iframe
        :byline => 0,             # Hide video byline
        :badge => 0,              # Hide vendor logo
        :portrait => 0,           # Don't show user's portrait
        :autoplay => 1,           # Autostart the video
        :title => 0               # Hide video title
      }
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:Wistia][:id]
      settings = {
        :autoPlay => true,      # Autostart the video
        :chromeless => true,    # Don't show any controls
        :playerColor => 'black' # Change player outlines to black
      }
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:DailyMotion][:id]
      settings = {
        :autoplay => 1,         # Autostart the video 
        :chromeless => 1,       # Don't show any controls 
        :info => 0,             # Hide video information
        :logo => 0,             # Hide vendor logo
        :related => 0           # Don't show related videos at end
      }
    elsif self.config['video_vendor'] == VIDEO_VENDORS[:HTTPVideo][:id]
      settings = {
        :autoplay => 1,         # Autostart the video
        :end => self.duration,  # Stop it around the duration
        :controls => 0,         # Don't show any controls
        :http_video => true     # Pass http video
      }
    end
    {:path => player_url(settings)}
  end

  def render_preview
    if self.config['video_vendor'] == RemoteVideo::VIDEO_VENDORS[:YouTube][:id] || 
       self.config['video_vendor'] == RemoteVideo::VIDEO_VENDORS[:Vimeo][:id] ||
       self.config['video_vendor'] == RemoteVideo::VIDEO_VENDORS[:Wistia][:id] || 
       self.config['video_vendor'] == RemoteVideo::VIDEO_VENDORS[:DailyMotion][:id]
      player_settings = { :end => self.duration, :rel => 0, :theme => 'light', :iv_load_policy => 3 }
      results = self.config['preview_code']
    elsif self.config['video_vendor'] == RemoteVideo::VIDEO_VENDORS[:HTTPVideo][:id]
      results = self.config['preview_code']
    end

    results
  end
end
