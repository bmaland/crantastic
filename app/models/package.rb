# == Schema Information
# Schema version: 20090727140821
#
# Table name: package
#
#  id                  :integer         not null, primary key
#  name                :string(255)
#  description         :text
#  created_at          :datetime
#  latest_version_id   :integer
#  updated_at          :datetime
#  package_users_count :integer         default(0), not null
#

class Package < ActiveRecord::Base

  # Specifies the fields that should be indexed with Solr. Note that the tags
  # association is indexed, so if e.g. a package is tagged with
  # 'ItemResponseTheory' it will show up in the result list if someone searches
  # for 'response theory'. The =name= field is boosted, and the whole document
  # is boosted based on how many users the package has.
  #
  # References:
  # * http://pivotallabs.com/users/rolson/blog/articles/974-boosting-with-acts-as-solr
  acts_as_solr :fields => [{:name => {:boost => 5.0}}, :description, :tags],
               :boost => Proc.new { |pkg| pkg.package_users_count.to_f }

  has_many :versions, :order => "id DESC", :dependent => :destroy
  has_many :package_ratings, :dependent => :destroy
  has_many :package_users, :dependent => :destroy
  has_many :reviews, :dependent => :destroy
  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings, :uniq => true do
    # @param [String, Class] type E.g. Priority or TaskView
    def type(type)
      proxy_owner.tags.all(:conditions => ["type = ?", type.to_s])
    end
  end

  # We cache the latest version id
  belongs_to :latest_version, :class_name => "Version"
  alias :latest :latest_version

  fires :new_package, :on                => :create,
                      :subject           => :self,
                      :secondary_subject => :self # yes 2x package

  named_scope :recent, :order => "#{self.table_name}.created_at DESC",
                       :include => :latest_version,
                       :conditions => "#{self.table_name}.created_at IS NOT NULL",
                       :limit => 50

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :in => 2..255

  # We can't validate the presence of a latest_version_id here, since we
  # create packages before versions are associated. In conclusion, we have
  # to be careful and ideally use transactions when creating packages to avoid
  # inconsistent data in the database.

  def self.find_by_param(id)
    self.find_by_name(id.gsub("-", ".")) or raise ActiveRecord::RecordNotFound
  end

  ## No. of packages to show per page.
  def self.per_page; 50; end

  ## Search On Name of Package.
  def self.paginating_search(q, search_results_page)
    q.strip.downcase!

    paginate({ :conditions => [ 'LOWER(package.name) LIKE ?', '%' + q + '%'],
               :include => [{:latest_version => :maintainer}],
               :order => 'LOWER(package.name)',
               :page => search_results_page })
  end

  def self.search(q, limit=self.per_page)
    qq = '%' + q + '%'
    m = Amatch::Levenshtein.new(q.to_s)
    Package.all(:conditions =>
                ['LOWER(package.name) LIKE LOWER(?) OR LOWER(version.description) LIKE ?', qq, qq],
                :limit => limit, :include => :latest_version).sort_by { |p| -m.similar(p.name) }
  end

  def <=>(other)
    self.name.downcase <=> other.name.downcase
  end

  # If updated_at is nil (which is the case for some older records), return
  # created_at as the value for updated_at. This is required because e.g. the
  # sitemap relies on proper updated_at values.
  def updated_at
    super || self.created_at
  end

  # @return [Fixnum] Number of ratings for this package for the given aspect
  def rating_count(aspect="overall")
    PackageRating.count(:conditions => ["package_id = ? AND aspect = ?",
                                        self.id, aspect])
  end

  # Rounded average rating for this package
  def average_rating(aspect="overall")
    PackageRating.calculate_average(self, aspect)
  end

  def to_param
    name.gsub(".", "-")
  end

  def to_s
    name
  end

  def url_for(site)
    case site
    when "google" then
      "http://www.google.com/search?q=" +
        CGI.escape("#{name} cran OR " +
                   "r-project -inurl:contrib -inurl:doc/packages -inurl:CRAN")
    when "scholar" then
      "http://scholar.google.com/scholar?q=" + CGI.escape(name)
    when "rhelp" then
      "http://finzi.psych.upenn.edu/cgi-bin/namazu.cgi" +
        "?idxname=Rhelp02a&idxname=Rhelp01&query=" + CGI.escape(name)
    when "rdevel" then
      "http://finzi.psych.upenn.edu/cgi-bin/namazu.cgi" +
        "?idxname=R-devel&query=" + CGI.escape(name)
    when "graphical_manual" then
       "http://bm2.genes.nig.ac.jp/RGM2/pkg.php?p=" + CGI.escape(name)
    end
  end

  # Finds related packages, based on common tags.
  # Adapted from acts_as_taggable_on
  def find_related_packages(options = {})
    tags_to_find = self.tags.collect { |t| t.id }
    cols = self.class.column_names.collect { |c| "package.#{c}" }.join(",")

    conditions = {
      :select     => "package.*, COUNT(tag.id) AS count",
      :from       => "package, tag, tagging",
      :conditions => ["package.id != #{self.id} AND " +
                      "package.id = tagging.package_id AND " +
                      "tagging.tag_id = tag.id AND " +
                      "tag.id IN (?)", tags_to_find],
      :group      => cols,
      :order      => "count DESC"
    }.update(options)

    self.class.find(:all, conditions)
  end

end
