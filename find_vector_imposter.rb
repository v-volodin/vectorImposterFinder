#!/usr/bin/env ruby
# coding: utf-8

# This script finds svg and pdf files containing raster images.

require 'pdf/reader'
require 'rexml/document'

module FindVectorImposter
  class PDFInspector
    def does_contain_raster(file)
      PDF::Reader.open(file) do |reader|
        page = reader.page(1)
        xobjects = page.xobjects
        return false if xobjects.empty?

        xobjects.each do |_name, stream|
          case stream.hash[:Subtype]
          when :Image
            return true
          when :Form
            process_page(PDF::Reader::FormXObject.new(page, stream))
          end
        end
        false
      end
    end
  end

  class SVGInspector
    def does_contain_raster(file)
      xml_string = File.read(file)
      doc = REXML::Document.new(xml_string)
      doc.elements.each('//image') do |image_element|
        href = image_element.attributes['href']
        return true if href
      end
      false
    end
  end
end

if ARGV.empty?
  puts 'Specify the path to the folder.'
  exit
end

folder_path = ARGV[0]

unless Dir.exist?(folder_path)
  puts 'The specified folder does not exist.'
  exit
end

pdf_inspector = FindVectorImposter::PDFInspector.new
svg_inspector = FindVectorImposter::SVGInspector.new
pdf_files = Dir.glob(File.join(folder_path, '**', '*.pdf'))
svg_files = Dir.glob(File.join(folder_path, '**', '*.svg'))
vector_imposters_in_svg_found = 0
vector_imposters_in_pdf_found = 0

puts 'Checking pdf files...'

if pdf_files.empty?
  puts 'There are no PDF files in the specified folder.'
else
  pdf_files.each do |file|
    if pdf_inspector.does_contain_raster(file)
      puts "#{File.basename(file)}"
      vector_imposters_in_pdf_found += 1
    end
  end
  puts "#{vector_imposters_in_pdf_found} vector imposters in pdf files found"
end

puts 'Checking svg files...'

if svg_files.empty?
  puts 'There are no SVG files in the specified folder.'
else
  svg_files.each do |file|
    if svg_inspector.does_contain_raster(file)
      puts "#{File.basename(file)}"
      vector_imposters_in_svg_found += 1
    end
  end
  puts "#{vector_imposters_in_svg_found} vector imposters in svg files found"
end
