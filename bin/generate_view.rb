require File.expand_path('../../lib/local_reconfigure', __FILE__)

include LocalReconfigure

case ARGV[0]

	when 'db'
		generate_view_db

	when 'known'
		generate_view_known

	when 'md5'
		generate_view_md5
		
	when 'rvm_version'
		generate_view_rvm_version
	else
		$stderr.puts "Please specifiy a view to generate (md5, db, known or rvm_version)\n"
end
