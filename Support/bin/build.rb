#!/usr/bin/env ruby
# encoding: utf-8

require ENV['TM_BUNDLE_SUPPORT'] + '/bin/fcshd.rb'
require ENV['TM_BUNDLE_SUPPORT'] + '/bin/as3project.rb'

require File.expand_path(File.dirname(__FILE__)) + '/../lib/add_lib'

require 'fm/flex_mate'
require 'fm/sdk'

#Require beein in a project
FlexMate.require_tmproj

#Add flex to path
FlexMate::SDK.add_flex_bin_to_path

#Generate the beautiful header
FCSHD.generate_view

# run the compiler and print filtered error messages
FCSHD.start_server
AS3Project.compile