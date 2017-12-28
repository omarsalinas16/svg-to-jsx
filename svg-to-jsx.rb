#!/usr/local/bin/ruby -w

begin
	require "fileutils"
	require "optparse"
	require "nokogiri"
	require "nokogiri-pretty"
rescue Gem::LoadError
	raise `This tool required the following gems:
	fileutils
	optparse
	nokogiri
	nokogiri-pretty`
end

# Methods

class FileHelper
	def self.parse_directory_argument(arg)
		File.expand_path(arg)
	end
	
	def self.directory_exists?(path)
		File.directory?(File.expand_path(path))
	end
	
	def self.file_exists?(path)
		File.exists?(File.expand_path(path))
	end
	
	def self.get_file_name(file_path, ext = "")
		File.basename(File.expand_path(file_path), ext)
	end
	
	def self.list_all_files_in_dir(path, recursive = false, ext = "")
		full_path = "#{File.expand_path(path)}"
	
		if recursive
			full_path << "/**"
		end
	
		full_path << "/*#{ext}"
	
		return Dir[full_path]
	end
end

class XMLFormatter
	def self.read_file_content(file_path)
		if !FileHelper.file_exists?(file_path)
			return ""
		end
		
		content = ""
	
		File.foreach(file_path) do |line|
			content << line
		end
	
		return content
	end

	def self.strip_xml_header(content)
		content.sub('<?xml version="1.0" encoding="ISO-8859-1"?>',"")
	end

	def self.process_xml_file(file_path)
		content = read_file_content(file_path)
		content.encode("UTF-8")
	
		input_content = Nokogiri::XML::DocumentFragment.parse content
		parsed_content = input_content.to_xml
	
		xml = Nokogiri::XML parsed_content
		pretty = xml.human
	
		output = strip_xml_header(pretty).strip().gsub!("  ", "\t")
	
		return output
	end
end

class SVGtoJSX
	TEMPLATE = <<-JSX
import React from 'react';
import { pure } from 'recompose';

import './Icon.css';

const %{name}Icon = ({ ...props }) => (
	<div className="Icon">
%{content}
	</div>
);

const Pure%{name}Icon = pure(%{name});

export default Pure%{name}Icon;
JSX

	def self.string_to_CamelCase(string)
		final = ''

		if string.include?('_')
			final = string.split('_').collect(&:capitalize).join
		elsif string.include?('-')
			final = string.split('-').collect(&:capitalize).join
		else
			final = string.capitalize
		end

		return final
	end

	def self.parse_to_jsx_component(name, content)
		tabbed_content = ''

		content.each_line do |line|
			tabbed_content << line.prepend("\t\t")
		end

		data = { name: name, content: tabbed_content }
		return TEMPLATE % data
	end
end

# Main program

EXT = ".svg"

source_path = ""
output_path = ""

options = {
	resursive: false
}

op = OptionParser.new do |parser|
	parser.banner = "Usage: svg-to-jsx.rb <source_path> <output_path> [options]"

	parser.on("-r", "--[no-]recursive", "Whether to search for files inside subfolders or not.") do |value|
		options[:recursive] = value
	end

	parser.on("-h", "--help", "Show this help message") do ||
		puts "\n #{parser}"
		exit!
	end
end

op.parse!

source_path = FileHelper.parse_directory_argument(ARGV[0])
output_path = FileHelper.parse_directory_argument(ARGV[1])

raise "\nNo source path input" unless source_path
raise "\nNo output path input" unless output_path

source_path_exists = FileHelper.directory_exists?(source_path)

raise "\nSource directory not found or does not exists" unless source_path_exists

unless FileHelper.directory_exists?(output_path)
	FileUtils.mkdir_p(output_path)
end

output_path_exists = FileHelper.directory_exists?(output_path)

raise "\nOutput directory does not exist or could not be created due to permission errors" unless output_path_exists

files_array = FileHelper.list_all_files_in_dir(source_path, options[:recursive], EXT)

puts "\nFiles found: #{files_array.length}\n\n"

files_array.each do |file_path|
	name = FileHelper.get_file_name(file_path, EXT)
	capitalized_name = SVGtoJSX.string_to_CamelCase(name);

	File.open("#{output_path}/#{capitalized_name}.js", "w") do |f|
		puts "Created new file: #{capitalized_name}.js"
		content = XMLFormatter.process_xml_file(file_path)

		jsx = SVGtoJSX.parse_to_jsx_component(capitalized_name, content)

		f.write(jsx)
	end
end