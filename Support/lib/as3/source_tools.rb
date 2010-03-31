#!/usr/bin/env ruby -wKU
# encoding: utf-8

require "#{ENV['TM_BUNDLE_SUPPORT']}/bin/as3project"
require 'digest/md5'
require 'rexml/document'

# ActionScript 3 utility methods for inspecting source directories, paths and
# packages.
#
module SourceTools

  # Returns an colon seperated list of directory names
  # that are commonly used as the root directory for source files.
  #
  # See 'Settings' bundle preference to override defaults.
  #
  def self.common_src_dir_list
    src_dirs = ENV['TM_AS3_USUAL_SRC_DIRS']
    src_dirs = "src:lib:source:test" if src_dirs == nil
    src_dirs
  end

  # Returns an array of directory names that are commonly used
  # as the root directory for source files.
  #
  def self.common_src_dirs
    src_dirs_matches = []
    AS3Project.source_path_list.each do |source_path|
      source_path.gsub("/",".")
      src_dirs_matches << source_path
    end
    src_dirs_matches << common_src_dir_list.split(":")
    src_dirs_matches
  end

  # Loads all paths found within the current project that have a filename which
  # contains the requested word.
  #
  def self.search_project_paths(word)

    project = "#{ENV['TM_PROJECT_DIRECTORY']}"

    best_paths = []
    package_paths = []

    # Collect all .as and .mxml files with a filename that contains the search
    # term. When used outside a project this step is skipped.
    TextMate.each_source_file do |file|

      if file =~ /\b#{word}\w*\.(as|mxml)$/i

        path = file.sub( project, "")
        path = truncate_to_src(path)
        path = path.gsub(/\.(as|mxml)$/,'').gsub( "/", ".").sub(/^\./,'')

        if path =~ /\.#{word}$/i
          best_paths << path
        else
          package_paths << path
        end

      end

    end

    { :exact_matches => best_paths, :partial_matches => package_paths }

  end

  # Loads all paths stored in the bundle lookup that have a filename which
  # contains the requested word.
  #
  def self.search_bundle_paths(word)

    help_toc = File.dirname(__FILE__) + '/../../data/doc_dictionary.xml'

    best_paths = []
    package_paths = []

    # Open Help dictionary and find matching lines
    toc = ::IO.readlines(help_toc)
    toc.each do |line|

      if line =~ /href='([a-zA-Z0-9\/]*\b#{word}\w*)\.html'|([a-zA-Z0-9\/]*\/package\.html##{word}\w*)\(\)'/i

        if $2
          path = $2.gsub('package.html#', '').gsub('/', '.')
        else          
            path = $1.gsub('/', '.')
        end

        if path =~ /(^|\.)#{word}$/i
          best_paths << path
        else
          package_paths << path
        end

      end
    end

    { :exact_matches => best_paths, :partial_matches => package_paths }

  end
  
  def self.search_library_paths(word)
	  #Unpack the swcs
		unpack_swcs
		
		#Result arrays
		best_paths = []
		package_paths = []
		
		# for each library entry
		swc_definitions.each do |definition|
		  #See if it matches
      path = definition.sub(":",".")
      if path =~ /\.#{word}$/i
				best_paths << path
			elsif path =~ /\.#{word}.*$/i
			  package_paths << path
			end
		end
		
		{ :exact_matches => best_paths, :partial_matches => package_paths }
	end
	
	# Searches for the definition of the given uri in
	# the library's SWCs
	#
	# Returns a boolean
	def self.has_definition_in_swc?(uri)
	  
	  # Make sure our library is up to date
	  unpack_swcs
	  
	  # Search in catalog
	  swc_definitions.each do |definition|
	    return true if definition.sub('.','/').sub(':','/') == uri
	  end
	  
	 false
	end
	

  # Loads bundle, project and library paths.
  #
  def self.search_all_paths(word)

    pp = search_project_paths(word)
    bp = search_bundle_paths(word)
		lp = search_library_paths(word)
		
		e = pp[:exact_matches] + bp[:exact_matches] + lp[:exact_matches]
		p = pp[:partial_matches] + bp[:partial_matches] + lp[:partial_matches]

    e.uniq!
    p.uniq!

    { :exact_matches => e, :partial_matches => p }

  end

  # Takes the path and truncates it to the last matching 'common_src_dir'.
  #
  def self.truncate_to_src(path)
    common_src_dirs.each do |remove|
      path = path.gsub( /^.*\b#{remove}\b(\/|$)/, '' );
    end
    path
  end

  # Finds, and where sucessful returns, the package path for the specified
  # class (word is used as parameter here as it may be a partial class name).
  # Packages paths are resolved via doc_dictionary.xml, which contains flash, fl,
  # and mx paths, and the current tm project (when available).
  #
  # Where mulitple possible matches are found these are presented to the user
  # using Textmate::UI.menu with the most probable match at the top of the menu.
  #
  def self.find_package(word="")

    TextMate.exit_show_tool_tip("Please select a class to\nlocate the package path for.") if word.empty?

    all_paths = search_all_paths(word)

    best_paths = all_paths[:exact_matches]
    package_paths = all_paths[:partial_matches]

    if package_paths.size > 0 and best_paths.size > 0
      package_paths = best_paths + ['-'] + package_paths
    else
      package_paths = best_paths + package_paths
    end

    TextMate.exit_show_tool_tip("Class not found") if package_paths.empty?

    if package_paths.size == 1

      package_paths.pop

    else

      # Move any exact hits to the top of the list.
      best_paths = package_paths.grep( /\.#{word}$/ )

      i = TextMate::UI.menu(package_paths)
      TextMate.exit_discard() if i == nil
      package_paths[i]

    end

  end
  
  # Takes the path paramater and lists all classes found within that directory.
  #
  # Path can be either a package declaration, ie org.helvector.core.* or a file
  # path.
  #
  def self.list_package(path)
    
    #if path is a package declaration convert it to a file path.
    path.gsub!('.','/') unless path =~ /\//
    path.sub!(/\/\*$/,'')
    
    unless File.exist?(path)
      path = ENV['TM_PROJECT_DIRECTORY'] + "/src/" + path
    end
    
    return nil unless File.exist?(path)
    
    classes = []
    
    Dir.foreach(path) do |f|
      classes << File.basename(f,$1) if f =~ /(\.(as|mxml))$/
    end
    
    classes
    
  end
  
  # Unpack all swc in the library path
  # searching for possible classes
	def self.unpack_swcs
	  
	  project = "#{ENV['TM_PROJECT_DIRECTORY']}"
	  
	  #Loop through library, searching for SWC paths
	  AS3Project.libray_path_list.each do |p|
	    
	    #Where to unpack
	    lib_path = File.join(tmp_swc_dir, p.sub("/","_"))
	    
	    #Create a directory in the temp folder for holding the unpacked files
	    Dir.mkdir lib_path unless File.directory? lib_path
	    
	    #Unpack files in this folder
	    Dir.entries(File.join(project, p)).each do |entry|
	      #is it an swc?
	      if File.extname(entry) == ".swc"
	        
	        #Full path to file
	        swc_path = File.join(project, p, entry)
	        extraction_path = File.join lib_path, entry.sub(".swc","")
	        
	        #Checking if file changed
	        stamp = File.stat(swc_path).mtime.to_i.to_s
	        
	        #checking if the file need to be extracted
	        if !File.exists? File.join(extraction_path, stamp)
	          #removing old entries
	          `rm -rf #{extraction_path}`
	          #swc found, time to unzip it
            `unzip #{swc_path} -d #{extraction_path}`
  	        #create md5
  	        `touch #{File.join(extraction_path, stamp)}`
	        end

	      end
	    end
	    
	  end
	end
	
	#SWC working folder
	@dir = nil
	def self.tmp_swc_dir
	  return @dir unless @dir.nil?
	  
	  #Create unique dir per project
	  @dir = "/tmp/fcshd/swcs" + Digest::MD5.hexdigest("#{ENV['TM_PROJECT_DIRECTORY']}")
	  
	  #Check if temp dir exists, then create
	  Dir.mkdir "/tmp/fcshd" unless File.directory? "/tmp/fcshd"
	  Dir.mkdir @dir unless File.directory? @dir
  	 
  	@dir 
	end
	
	
	
	# Generates a class structure for a given linkage
  # Used for SWC auto completion
  # 
  # Returns a string ex:
  # class MySwcClass extends Sprite
  #   {
  #     public function MySwcClass()
  #     {
  #       super();
  #     }
  #   }
  def self.skeleton_for_swc_class(linkage)
    #Getting a Swf object
    swf = swf_for_linkage linkage
    
    class_path = "#{ENV['TM_FLEX_PATH'].gsub(' ', '\\ ')}/lib/swfutils.jar:#{ENV["TM_BUNDLE_SUPPORT"].gsub(' ', '\\ ')}/bin/swf_parser"
    cmd = `java -cp #{class_path} Main #{swf} #{linkage.gsub('/','.')}`
    bones
	end
	
	def self.swc_definitions
	  cat = []
	  
	  # for each library entry
		Dir.entries(tmp_swc_dir).each do |entry|
		  if File.directory?(File.join(tmp_swc_dir, entry)) && entry != "." && entry != ".."
		    
		    #Get all definitions
    	  Dir.entries(File.join(tmp_swc_dir, entry)).each do |lib_path|
    	    if lib_path != "." && lib_path != ".."
    	      
    	      #Open XML Catalog
            catalog = REXML::Document.new( File.read(File.join(tmp_swc_dir, entry, lib_path, "catalog.xml")))
            catalog.elements.each("*/libraries/library/script/def") do |definition|
              
              cat << definition.attributes["id"]
              
            end
    	    end
    	  end
    	end
		end
		
		cat
	end
	
	def self.swf_for_linkage(linkage)
	  # for each library entry
		Dir.entries(tmp_swc_dir).each do |entry|
		  if File.directory?(File.join(tmp_swc_dir, entry)) && entry != "." && entry != ".."
		    
		    #Get all definitions
    	  Dir.entries(File.join(tmp_swc_dir, entry)).each do |lib_path|
    	    if lib_path != "." && lib_path != ".."
    	      
    	      #Open XML Catalog
            catalog = REXML::Document.new( File.read(File.join(tmp_swc_dir, entry, lib_path, "catalog.xml")))
            catalog.elements.each("*/libraries/library/script/def") do |definition|

              #Is this it?
              return File.join(tmp_swc_dir, entry, lib_path, definition.parent.parent.attributes["path"] ) if definition.attributes["id"].sub(".","/").sub(":","/") == linkage
              
            end
    	    end
    	  end
    	end
  	end
	end
  
end

module  TextMate
  # Making source searching relative to the source paths
  def TextMate.each_source_file (&block)
    project_dir = ENV['TM_PROJECT_DIRECTORY']
    return if project_dir.nil?

    AS3Project.source_path_list.each do |sp|
        fullpath = File.join(project_dir, sp)
        TextMate.scan_dir(fullpath, block, ProjectFileFilter.new)
    end

  end
end