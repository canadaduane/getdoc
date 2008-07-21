# Copyright (C) 2008  Duane Johnson
# duane.johnson@gmail.com
#
# Example Usage:
# my_doc = GetDoc.new("dcjnq5tv_41gkdrv5dj")
# <%= my_doc %>
#
# License: MIT
begin
  require 'rubygems'
  require 'open-uri'
  require 'hpricot'
  
  class GetDoc
    attr_accessor :transformation
    
    CACHE_DIR = File.join(File.dirname(__FILE__), "..", "cache")
    CACHE_REFRESH = 1 * 60 # 1 minute
    
    GOOGLE_URL = "http://docs.google.com/View?id=%s"
    GOOGLE_TRANSFORM =
      proc do |hpricot|
        (hpricot / "#doc-contents").inner_html.
          gsub(/(src|href)="(View\?|File\?)/, "\\1=\"http://docs.google.com/\\2")
      end
    
    def self.reset_cache
      FileUtils.rm Dir.glob(File.join(CACHE_DIR, "*"))
    end
    
    def initialize(docid, url = GOOGLE_URL, &block)
      @docid = docid
      @url = url
      @transformation = block || GOOGLE_TRANSFORM
    end
    
    def cache_file
      File.join(CACHE_DIR, @docid.gsub("/", "-"))
    end
    
    def cache_age
      Time.now - File.ctime(cache_file)
    end
    
    def get_live_doc
      doc = Hpricot(open(@url % @docid))
      html = @transformation[doc]
    rescue OpenURI::HTTPError => e
      "Document '#{@docid}' not accessible (#{e})"
    rescue RuntimeError => e
      if e.to_s[/redirection forbidden/]
        "Document '#{@docid}' is not public / published."
      else
        e.to_s
      end
    end
  
    def get_cached_doc
      IO.read(cache_file)
    rescue Errno::ENOENT
      "Cached doc '#{@docid}' not found."
    end
  
    def save_doc(html)
      File.open(cache_file, "w") { |f| f.print html }
      html
    rescue Errno::ENOENT, Errno::EACCES
      "Cache file could not be written: '#{cache_file}'."
    end
  
    def cache_too_old?
      cache_age > CACHE_REFRESH
    rescue Errno::ENOENT
      true
    end
  
    def to_s
      if cache_too_old?
        save_doc(get_live_doc)
      else
        get_cached_doc
      end
    end
  end
  
  ""
rescue Exception => e
  e.to_s
end
