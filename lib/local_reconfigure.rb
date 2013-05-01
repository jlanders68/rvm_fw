require 'yaml'

module LocalReconfigure

	RVMFW_ROOT = File.expand_path('../../', __FILE__)

	#the idea is that this script will allow users to upload rubies into public/ and then run this script to generate the config/rubies.yml

	def generate_local_rubies_yml
		#load the config/rubies.yml.example
		#rubies = YAML.load(File.read(File.join(RVMFW_ROOT, 'config/rubies.yml.example')))
		rubies = {}
		
		#get a list of all sources in public
		dirs = ['rubygems/*', 'ruby-lang/*/*', 'packages/*/*']
		dirs.each do |dir|
			glob = File.join(RVMFW_ROOT, 'public/rubies/', dir)
			Dir.glob(glob) do |file|
				branch = file.split('public/rubies/').last
				dir, fn = File.split(branch)

				type = dir.split('/').compact.first
				details = {:dir => dir, :filename => fn, :md5 => `md5sum #{file}`.split(/\s+/).first, :type=>type}

				basename = fn.sub(/\.(?:tar\.gz|tar\.bz2|tar\.xz|tgz|zip)$/, '')
				case type
					when 'rubygems', 'packages'
						details[:version] = basename.split('-').last
					when 'ruby-lang'
						bits = basename.split(/[ -]/)
						if bits[0] == 'ruby' and bits[1] == 'enterprise'
							details[:version] = bits[2]
							details[:patch] = bits[3]
							details[:ruby_interpreter] = 'ree'
						else
							case bits[0]
								when 'ruby'
									details[:version] = bits[1]
									details[:patch] = bits[2]
									details[:ruby_interpreter] = 'ruby'
								when 'jruby'
									details[:version] = bits[2]
									details[:ruby_interpreter] = 'jruby'
								when 'MacRuby'
									details[:version] = bits[1]
									details[:ruby_interpreter] = 'MacRuby'
								when 'rubinius'
									details[:version] = bits[1]
									details[:patch] = bits[2]
									details[:ruby_interpreter] = 'rubinius'
							end
						end
						
				end
				rubies[fn] = details
			end
		end
		#save the hash as yaml into config/rubies.yml

		File.open(File.join(RVMFW_ROOT, 'config/local_rubies.yml'), "w") do |f|
			f.write rubies.to_yaml
		end
	end

end


