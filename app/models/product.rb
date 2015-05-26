class Product
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Pagination

	require 'readability'
	require 'open-uri'
	require 'net/http'

  has_many :activities
  has_many :recommendations

  before_save :set_deleted
  before_create :date
  before_create :deleted_on

  validates_presence_of :external_id, :status
  STATUS_OPTIONS = %w(active inactive)
  validates :status, :inclusion => {:in => STATUS_OPTIONS}

  field :external_id, type: String
  field :resource, type: Hash
  field :status, type: String, default: -> { 'active' }
  field :deleted_on, type: DateTime

  # todo: deprecate fields below
  field :date, type: DateTime
  field :url, type: String
  field :title, type: String
  field :short_content, type: String
  field :full_content, type: String
  field :source, type: String
  field :category, type: String
  field :language, type: String
  field :icon, type: String
  field :image, type: String

  index({ external_id: -1 }, {unique: true, drop_dups: true})
  index({ external_id: 1, deleted_on: -1 })
  index({ deleted_on: 1 })
  index({ date: 1, deleted_on: -1 })

  scope :active, ->{ where(status: 'active') }

  def set_deleted
    self.deleted_on = Time.now if status_was=='active' and status=='inactive'
    self.deleted_on = nil if status_was=='inactive' and status=='active'
    if status_changed? and !new_record? and status=='inactive'
      result = Modules::Barbante.delete_product external_id, self.deleted_on
      raise result[:message] unless result[:success]
    end
  end

  def date
    self[:date] ||= self[:created_at]
  end

  def deleted_on
    # force mongodb to save field with null, otherwise it doesn't save the field at all
    self[:deleted_on] ||= status=='active' ? nil : Time.now
  end

  def process
    if self.full_content.blank? || self.language.blank?
      self.full_content = Product.get_content self.url if self.full_content.blank? and Settings[:product][:fetch_url_content]
      self.language = self.get_language if self.language.blank? and Settings[:product][:fetch_content_language]
      self.save if self.changed?
    end

    unless status=='inactive'
      return Modules::Barbante.process_product self
    end

    {success: true}
  end

  def self.get_content(url=nil)
    return nil if url.blank?
    source = self.fetch(url)
    content = Readability::Document.new(source).content
    content = ActionView::Base.full_sanitizer.sanitize(content)
    content.gsub("  ","")
  end

  def self.fetch(uri_str, limit = 10)
    return nil if limit==0
    return nil if uri_str.blank?

    begin
      # puts "Fetching from url #{uri_str}"
      response = Net::HTTP.get_response(URI(uri_str))
    rescue Exception => e
      # puts "Error fetching from url #{uri_str}: #{e.message}"
      e.backtrace.each{|line| puts " > #{line}"}
      return nil
    end
    return nil unless /text\//.match(response['content-type'])

    case response
    when Net::HTTPSuccess then
      response.body
    when Net::HTTPRedirection then
      location = response['location']
      # warn "redirected to #{location}"
      fetch(location, limit - 1)
    else
      nil
    end
  end

  def get_language
    return language.to_sym if language
    return full_content.language if full_content and !full_content.blank?
    return short_content.language if short_content and !short_content.blank?
    return title.language if title and !title.blank?
    nil
  end

  def get_content
    return full_content if full_content and !full_content.blank?
    return short_content if short_content and !short_content.blank?
    nil
  end

  def mark_deleted
    self.update(status: 'inactive', deleted_on: Time.now) unless self.deleted_on
  end

  def map_field(index)
    begin
      mapto = Settings[:product][:fields][index].split('.').map{|field| "['#{field}']"}.join('')
      eval("self#{mapto}")
    rescue
      nil
    end
  end

end
