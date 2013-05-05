require 'yaml'

module LocalReconfigure

	RVMFW_ROOT = File.expand_path('../../', __FILE__)

	class Resource
		attr_accessor :version
		attr_accessor :patch
		attr_accessor :current_for_version
		attr_accessor :current_for_all_versions
		attr_accessor :filename
		attr_accessor :dir 
		attr_accessor :md5

		def initialize(path, version, patch)
			@dir, @filename = File.split(path)
			@version = version
			@patch = patch
			@dir.sub!(RVMFW_ROOT + '/public/', '')
			@md5 = `md5sum #{path.gsub(' ', '\ ')}`.split(/\s+/).first
		end

	end

	class ResourceSet < Array
		class << self; attr_accessor :filename_regex end
		class << self; attr_accessor :stable_patch_number_regex end

		def self.subclasses
    			ObjectSpace.each_object(Class).select { |klass| klass < self }
  		end

		def self.type
			self.instance_variable_get('@type') || self.name.split('::').last.sub(/Set$/, '').downcase.intern
		end

		def self.file_glob
			self.instance_variable_get('@file_glob') || '*'
		end

		def self.public_dir
			self.instance_variable_get('@public_dir') || File.join('rubies', self.name.split('::').last.sub(/Set$/, '').downcase)
		end

		def self.has_patch_number
			self.instance_variable_get('@has_patch_number') || false
		end

		def self.generate_known_line(r)
			
			kl = "#{self.type}"
			if r.current_for_all_versions
				kl += "[-#{r.version}]"
			else
				kl += "-#{r.version}"
			end
				
			if self.has_patch_number
				if r.current_for_version
					kl += "[-#{r.patch}]"
				else
					kl += "-#{r.patch}"
				end
			end
			return kl
		end

		def initialize
			super
		end

		def read_dir
			root_dir = File.join(RVMFW_ROOT, 'public')
			glob = File.join(root_dir, self.class.public_dir, self.class.file_glob)
			Dir.glob(glob) do |branch|
				dir, fn = File.split(branch)

				basename = fn.sub(/\.(?:tar\.gz|tar\.bz2|tar\.xz|tgz|zip)$/, '')
				
				if basename =~ self.class.filename_regex
					version = $1 or raise StandardError, "no version number found in name for #{fn}.  file basename (#{basename}) should match the regex #{self.class.filename_regex}"
					patch = $2 or raise StandardError, "no patch number found in name for #{fn}.  file basename (#{basename}) should match the regex #{self.class.filename_regex}" if self.class.has_patch_number
				else
					raise StandardError, "no version number found in name for #{fn}.  file basename (#{basename}) should match the regex #{self.class.filename_regex}"
				end
				self.push Resource.new(branch, version, patch)
			end
		end

		def sorted_versions
			if self.class.has_patch_number
				return self.sort{|a,b| "#{a.version}-#{a.patch}" <=> "#{b.version}-#{b.patch}"}
			else
				return self.sort{|a,b| a.version <=> b.version}
                	end
		end

		def generate_known
			out = ""
			self.sorted_versions.each do |r|
				out += self.class.generate_known_line(r)
				out += "\n"
			end
			return out
		end

		def select_current_version
			versions = self.sort{|a,b| b.version <=> a.version}
			unless self.class.has_patch_number
				current = versions.first
				if current
					current.current_for_all_versions = true
					current.current_for_version = true
				end
				return current
			end
			current_for_all_versions = nil
			versions.collect{|r| r.version}.sort.reverse.uniq.each do |v|
				current = self.select{|r| r.version == v and r.patch =~ self.class.stable_patch_number_regex}.sort{|b,a| a.patch <=> b.patch}.first
				if current
					current.current_for_version = true
					unless current_for_all_versions
						current_for_all_versions = current
						current.current_for_all_versions = true 
					end
				end
			end
			return current_for_all_versions
		end

		def current_version
			self.select{|r| r.current_for_all_versions}.first
		end

	end

	class RubyLangSet < ResourceSet
		@file_glob = '*/*'	
		@public_dir = 'rubies/ruby-lang'
		@filename_regex = /ruby-(\d+\.\d+\.\d+)-(\w+)/
		@has_patch_number = true
		@stable_patch_number_regex = /p\d+/
		@type = :rubylang

		def self.generate_known_line(r)
			out = "[ruby-]#{r.version}"
			if r.current_for_version
				out += "[-#{r.patch}]"
			else
				out += "-#{r.patch}"
			end
		end
	end

	class JRubySet < ResourceSet
		@file_glob = '*/*'	
		@filename_regex = /jruby-bin-(\d+\.\d+\.\d+)/
	end

	class MacRubySet < ResourceSet
		@filename_regex = /MacRuby (\d+\.\d+)/
	end

	class RbxSet < ResourceSet
		@filename_regex = /rubinius-(\d+\.\d+\.\d+)-(\d+)/
		@has_patch_number = true
		@stable_patch_number_regex = /\d+/
	end

	class ReeSet < ResourceSet
		@filename_regex = /ruby-enterprise-(\d+\.\d+\.\d+)-([\d\.]+)/
		@has_patch_number = true
		@stable_patch_number_regex = /[\d\.]+/
	end

	class RubygemsSet < ResourceSet
		@filename_regex = /rubygems-(\d+\.\d+\.\d+)/
	end

	class OpensslSet < ResourceSet
		@filename_regex = /openssl-([\d\.]+[a-z]?)/
		@public_dir = 'rubies/packages/openssl'
	end

	class RvmSet < ResourceSet
		@filename_regex = /(\d+\.\d+\.\d+)/
		@public_dir = 'rubies/packages/rvm'
	end

	class ReadlineSet < ResourceSet
		@filename_regex = /readline-([\d\.]+)/
		@public_dir = 'rubies/packages/readline'
	end
	class IconvSet < ResourceSet
		@filename_regex = /libiconv-([\d\.]+)/
		@public_dir = 'rubies/packages/iconv'
	end
	class CurlSet < ResourceSet
		@filename_regex = /curl-([\d\.]+)/
		@public_dir = 'rubies/packages/curl'
	end
	class ZlibSet < ResourceSet
		@filename_regex = /zlib-([\d\.]+)/
		@public_dir = 'rubies/packages/zlib'
	end
	class AutoconfSet < ResourceSet
		@filename_regex = /autoconf-([\d\.]+)/
		@public_dir = 'rubies/packages/autoconf'
	end
	class NcursesSet < ResourceSet
		@filename_regex = /ncurses-([\d\.]+)/
		@public_dir = 'rubies/packages/ncurses'
	end
	class PkgconfigSet < ResourceSet
		@filename_regex = /pkg-config-([\d\.]+)/
		@public_dir = 'rubies/packages/pkgconfig'
	end
	class GettextSet < ResourceSet
		@filename_regex = /gettext-([\d\.]+)/
		@public_dir = 'rubies/packages/gettext'
	end
	class Libxml2Set < ResourceSet
		@filename_regex = /libxml2-([\d\.]+)/
		@public_dir = 'rubies/packages/libxml2'
	end
	class LibxsltSet < ResourceSet
		@filename_regex = /libxslt-([\d\.]+)/
		@public_dir = 'rubies/packages/libxslt'
	end
	class GlibSet < ResourceSet
		@filename_regex = /glib-([\d\.]+)/
		@public_dir = 'rubies/packages/glib'
	end
	class LibyamlSet < ResourceSet
		@filename_regex = /yaml-([\d\.]+)/
		@public_dir = 'rubies/packages/libyaml'
	end
	class YamlSet < ResourceSet
		@filename_regex = /yaml-([\d\.]+)/
		@public_dir = 'rubies/packages/yaml'
	end

	FN_REGEXES = {	
			:rubygems => /rubygems-(\d+\.\d+\.\d+)/,
		   	:ruby_lang => /ruby-(\d+\.\d+\.\d+)-(\w+)/,
		 	:rbx => /rubinius-(\d+\.\d+\.\d+)-(\d+)/,
			:ree => /ruby-enterprise-(\d+\.\d+\.\d+)-([\d\.]+)/,
			:macruby => /MacRuby (\d+\.\d+)/,
 			:jruby => /jruby-bin-(\d+\.\d+\.\d+)/,
			:rvm => /(\d+\.\d+\.\d+)/,
			:openssl => /openssl-([\d\.]+[a-z]?)/,


			}

	#the idea is that this script will allow users to upload rubies into public/ and then run this script to generate the config/local_rubies.yml

	def generate_local_rubies
		rubies = {}
		#[RubyLangSet, RubygemsSet, JRubySet, ReeSet, MacRubySet, RbxSet, OpensslSet, RvmSet].each do |set|
		ResourceSet.subclasses.each do |set|
			rls = set.new
			puts set.type
			rls.read_dir
			rls.select_current_version
			rubies[set.type] = rls
		end
		return rubies
	end

	def generate_local_rubies_yml
		File.open(File.join(RVMFW_ROOT, 'config/local_rubies.yml'), "w") do |f|
			f.write generate_local_rubies.to_yaml
		end
	end

	def generate_known_text(local_rubies)
		out = ""
		out += "# MRI Rubies\n"
		out += local_rubies[RubyLangSet.type].generate_known
	
		out += "\n\n# JRuby\n"
		out += local_rubies[JRubySet.type].generate_known

		out += "\n\n# Rubinius\n"
		out += local_rubies[RbxSet.type].generate_known

		out += "\n\n# Ruby Enterprise Edition\n"
		out += local_rubies[ReeSet.type].generate_known

		out += "\n\n# Mac OS X Snow Leopard Or Newer\n"
		out += local_rubies[MacRubySet.type].generate_known
		return out
	end

	def generate_view_known
		File.open('views/known.erb', 'w') do |f|
			f.write generate_known_text(YAML.load(File.read('config/local_rubies.yml')))
		end
	end

	def generate_view_db
		File.open('views/db.erb', 'w') do |f|
			f.write generate_db_text(YAML.load(File.read('config/local_rubies.yml')))
		end
	end

	def generate_view_md5
		File.open('views/md5.erb', 'w') do |f|
			f.write generate_md5_text(YAML.load(File.read('config/local_rubies.yml')))
		end
	end

	def generate_view_rvm_version
		File.open('views/rvm_version.erb', 'w') do |f|
			f.write generate_rvm_version_text(YAML.load(File.read('config/local_rubies.yml')))
		end
	end
	
	def generate_rvm_version_text(local_rubies)
		local_rubies[RvmSet.type].current_version.version
	end

	def generate_db_text(local_rubies)
		rls = local_rubies[RubyLangSet.type]
		out = "
#General
niceness=0

# Rubies
interpreter=ruby
default_ruby=ruby
ruby_configure_flags=--disable-install-doc
ruby_url=<%= HOST %>/#{RubyLangSet.public_dir}
"

rls.sorted_versions.collect{|r| r.version[0,3]}.uniq.reverse.each do |v|
out += "ruby_#{v}_url=<%= HOST %>/#{RubyLangSet.public_dir}/#{v}\n"
end

out += "ruby_version=#{rls.current_version.version}
"

rls.sorted_versions.reverse.select{|r| r.current_for_version}.each do |r|
	out += "ruby_#{r.version}_patch_level=#{r.patch}\n"
end

out += "

rubygems_url=<%= HOST %>/rubies/rubygems
rubygems_version=#{local_rubies[RubygemsSet.type].current_version.version}
ruby_2.0.0_rubygems_version=2.0.0
ruby_1.9.3_head_rubygems_version=1.8.25

rbx_version=#{local_rubies[RbxSet.type].current_version.version}
rbx_#{local_rubies[RbxSet.type].current_version.version}_patch_level=#{local_rubies[RbxSet.type].current_version.patch}
rbx_url=<%= HOST %>/rubies/rbx

ree_version=#{local_rubies[ReeSet.type].current_version.version}
ree_configure_flags=--dont-install-useful-gems --no-dev-docs
ree_#{local_rubies[ReeSet.type].current_version.version}_patch_level=#{local_rubies[ReeSet.type].current_version.patch}
ree_#{local_rubies[ReeSet.type].current_version.version}_url=<%= HOST %>/rubies/ree

jruby_version=#{local_rubies[JRubySet.type].current_version.version}
jruby_url=<%= HOST %>/rubies/jruby

macruby_url=<%= HOST %>/rubies/macruby
macruby_version=#{local_rubies[MacRubySet.type].current_version.version}

# Packages
readline_url=<%= HOST %>/rubies/packages/readline
libiconv_url=<%= HOST %>/rubies/packages/iconv
curl_url=<%= HOST %>/rubies/packages/curl
openssl_url=<%= HOST %>/rubies/packages/openssl
openssl_version=#{local_rubies[OpensslSet.type].current_version.version}
zlib_url=<%= HOST %>/rubies/packages/zlib
autoconf_url=<%= HOST %>/rubies/packages/autoconf
ncurses_url=<%= HOST %>/rubies/packages/ncurses
pkg-config_url=<%= HOST %>/rubies/packages/pkgconfig
gettext_url=<%= HOST %>/rubies/packages/gettext
libxml2_url=<%= HOST %>/rubies/packages/libxml2
libxslt_url=<%= HOST %>/rubies/packages/libxslt
yaml_url=<%= HOST %>/rubies/packages/libyaml
glib_url=<%= HOST %>/rubies/packages/glib"

	end

	def generate_md5_text(local_rubies)
		out = ""
		ObjectSpace.each_object(Resource) do |r|
			out += "#{r.filename}=#{r.md5}\n"
		end
		return out
	end

end


