#!/usr/bin/env ruby -wKU

require 'yaml'  

module AS3Project     
    
    @fcshd = File.join(ENV["TM_BUNDLE_SUPPORT"], "bin/fcshd.py")
    @output_parser = File.join(ENV["TM_BUNDLE_SUPPORT"], "bin/parse_mxmlc_out.rb")
    @fcshd_gui = File.join(ENV["TM_BUNDLE_SUPPORT"], "bin/fcshd.rb")
    @project = ENV['TM_PROJECT_DIRECTORY']                               
    @build_yaml = nil
    
    def self.build_file
        if !@build_yaml:
            build_file_path = ENV['TM_FLEX_BUILD']          

            if !build_file_path
                build_file_path = File.join(@project, "build.yaml")
            end                                                   
                       
            if !file = File.open(build_file_path) rescue nil 
                printf('Could not find the build file at %s', build_file_path)
                exit
            end

            @build_yaml = YAML::load(file) rescue nil
            if !@build_yaml
              print "Something wrong when parsing YAML file"
              exit
            end    
        end        
        
        @build_yaml
    end    
    
    def self.get_path_list(attr_name)
        dirs = []                    
        
        if build_file.has_key?(attr_name)
            build_file.fetch(attr_name).each do |path|
                dirs.push path
            end
        end
        
        dirs
    end             
                
    def self.source_path_list
        get_path_list("source-path")
    end
                                          
    def self.libray_path_list
        get_path_list("library-path")
    end
    
    def self.mxmlc_source_path
        paths = source_path_list
        source_path = []
        
        paths.each do |path|
            source_path.push "-sp+="+File.join(@project, path)
        end                                 
        
        source_path.join(" ")
    end       
    
    def self.mxmlc_library_path
        paths = libray_path_list
        library_path = []
        
        paths.each do |path|
            library_path.push "-library-path+="+File.join(@project, path)
        end                                 
        
        library_path.join(" ")
    end                          
    
    def self.mxmlc_default_extra
        build_file.fetch("default")[0].fetch("extra") rescue ""
    end
    
    def self.mxmlc_default_debug                             
        build_file.fetch("default")[0].fetch("debug") rescue "false"
    end   
    
    def self.default_run_file
        build_file.fetch("default")[0].fetch("open") rescue ""
    end
    
    def self.mxmlc_applications
        apps = []
        
        if build_file.has_key?("applications")  
            build_file.fetch("applications").each do |app|
                if app && app.has_key?("class") && app.has_key?("output")
                    debug = app.fetch("debug") rescue mxmlc_default_debug
                    extra = app.fetch("extra") rescue mxmlc_default_extra
                    klass = File.join(@project, app.fetch("class"))
                    output = File.join(@project, app.fetch("output"))
                    library_path = mxmlc_library_path rescue ""
                    source_path = mxmlc_source_path rescue ""
                    
                    apps.push({"klass"=>app.fetch("class"), "mxmlc"=>"mxmlc #{klass} -o=#{output} -debug=#{debug} #{library_path} #{source_path} #{extra}"})
                end
            end
        end 
            
        apps
    end
    
    def self.asdocs_source_path()
        paths = build_file.fetch("asdoc").fetch("source-path") rescue []
        source_path = []
        
        paths.each do |path|
            source_path.push "-doc-sources+="+File.join(@project, path)
        end                                 
        
        source_path.join(" ")
    end
    
    def self.asdocs_exclude_dirs()
      build_file.fetch("asdoc").fetch("exclude-dirs") rescue []
    end
    
    def self.asdocs_exclude_classes()
      to_exclude = []
      
      asdocs_exclude_dirs.each do |path|
        source_path = Pathname.new(File.join(@project,path))
        Find.find(source_path.to_s) do |f|
          if f =~ /.as$/
            clean_path = Pathname.new(f).relative_path_from(source_path).to_s
            to_exclude.push("-exclude-classes+="+clean_path.gsub("/", ".").gsub(".as", ""))
          end
        end
      end
      
      to_exclude.join(" ")
    end
    
    def self.asdocs_title()
      build_file.fetch("asdoc").fetch("title") rescue "ActionScript Project"
    end
        
    def self.asdocs_footer()
      build_file.fetch("asdoc").fetch("footer") rescue "ActionScript Project"
    end
    
    def self.asdocs_output()
      File.join(@project, build_file.fetch("asdoc").fetch("output")) rescue ""
    end
    
    def self.asdocs()   
      
      require 'find'
      require 'pathname'
      
      if build_file.has_key?("asdoc")
        print("Running asdoc...<br /><br /><pre>")
        system("#{ENV["TM_FLEX_PATH"]}/bin/asdoc -output #{asdocs_output} #{asdocs_source_path} #{mxmlc_library_path} #{mxmlc_source_path} #{asdocs_exclude_classes} -warnings=false -window-title '#{asdocs_title}' -main-title '#{asdocs_title}' -footer '#{asdocs_footer}'")
        print "</pre>"
      else
        print "You have to set ASDocs settings on YAML file"
      end  
    end
    
    def self.compile()                                       
        mxmlc_applications.each do |app|
            printf('<b>Compiling %s</b>', app["klass"])
            
            system("            
              '#{@fcshd}' '#{app["mxmlc"]}' 2>&1 | '#{@output_parser}'; 
              if [ ${PIPESTATUS[0]} -eq 0 ]; then   
                '#{@fcshd_gui}' -success
              else
                '#{@fcshd_gui}' -fail
              fi                
            ")  
            print '<br /><br />' 
        end
    end 
    
    def self.run() 
        if default_run_file != ""
            system("open #{File.join(@project, default_run_file)}")
        end
    end
    
end     


def run       
    if !ARGV.empty?
        AS3Project.compile() if ARGV[0] == "-compile"
        AS3Project.run() if ARGV[0] == "-run"
        AS3Project.asdocs() if ARGV[0] == "-docs"
    end
        
end

run