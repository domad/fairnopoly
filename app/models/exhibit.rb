class Exhibit < ActiveRecord::Base
  extend Enumerize

  def self.exhibit_attrs
    [:article, :queue, :related_article,:article_id,:related_article_id]
  end

  enumerize :queue, in: [:donation_articles, :dream_team, :old, :fairnopoly_likes,
    :fair_highlights, :ecologic_highlights, :small_and_precious_highlights,
    :queue1, :queue2, :queue3, :queue4]

  belongs_to :article
  belongs_to :related_article, class_name: "Article"

  scope :one_day_exhibited, lambda { where("exhibits.exhibition_date IS NULL OR exhibits.exhibition_date >= ?", DateTime.now - 1.day) }
  scope :older_exhibited, lambda { where("exhibits.exhibition_date IS NOT NULL AND exhibits.exhibition_date < ?", DateTime.now - 1.day).order("RANDOM()") }
  scope :oldest_first, order("exhibits.created_at ASC")
  scope :article_active, where(" articles.state = 'active' ").joins(:article).includes(:article => [:images,:seller])
  scope :related_article_active, where("related_articles_exhibits.state = 'active' ").joins(:related_article).includes(:related_article => [:images,:seller])

  def self.independent_queue queue, count = 2
    exhibits = Exhibit.where(queue: queue).one_day_exhibited.article_active.oldest_first.limit count
    exhibits.each do |exhibit|
      exhibit.set_exhibition_date
    end
    exhibits = fill_exhibits( exhibits, queue, count ) unless exhibits.length >= count
    exhibits.map{ |exhibit| exhibit.article }
  end

  # Not used at the moment ---------------------------------------------------
  def self.relation_queue queue
    articles = []
    exhibit = Exhibit.where(queue: queue).one_day_exhibited.article_active.related_article_active.oldest_first.first
    if exhibit
      exhibit.set_exhibition_date
      articles << exhibit.article
      articles << exhibit.related_article
    end
    articles
  end
  # --------------------------------------------------------------------------

  # Currently only works for independent queues
  def self.all_from queue, page
    Article.joins(:exhibits).where("exhibits.queue = ?", queue).where(" articles.state = 'active' ").page page
  end

  def set_exhibition_date
    if self.exhibition_date == nil #or self.exhibition_date < (DateTime.now - 1.day) - maybe later. potentially removable. - KK
       # Because of the join the exhibition is readonly. We have to find it again.
       Exhibit.find(self.id).update_attribute(:exhibition_date, DateTime.now)
    end
  end

  private
    # Conditional scope, used when one_day_exhibited doesn't return enough results
    # @return [Array] exhibits plus older ones to fill empty spaces
    def self.fill_exhibits exhibits, queue, count
      filler_count = count - exhibits.length
      exhibits + Exhibit.where(queue: queue).where("exhibits.id NOT IN (?)", exhibits.map{|e| e.id } + [0] ).older_exhibited.article_active.limit(filler_count)
    end
end
